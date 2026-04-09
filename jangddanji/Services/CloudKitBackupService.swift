import Foundation
import CloudKit
import CoreLocation

enum CloudKitBackupError: LocalizedError {
    case noICloudAccount
    case backupFailed(String)
    case restoreFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noICloudAccount:
            return "iCloud 계정에 로그인되어 있지 않습니다. 설정에서 iCloud에 로그인해주세요."
        case .backupFailed(let msg):
            return "백업 실패: \(msg)"
        case .restoreFailed(let msg):
            return "복원 실패: \(msg)"
        case .deleteFailed(let msg):
            return "삭제 실패: \(msg)"
        }
    }
}

struct BackupStatus {
    var lastBackupDate: Date?
    var journeyCount: Int
    var hasBackup: Bool { journeyCount > 0 }
}

// MARK: - Restored Data

struct MergeResult {
    var uploaded: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
}

struct RestoredJourneyData {
    let id: UUID
    let title: String
    let startLocationName: String
    let startLatitude: Double
    let startLongitude: Double
    let endLocationName: String
    let endLatitude: Double
    let endLongitude: Double
    let startDate: Date
    let endDate: Date
    let totalDistance: Double
    let totalSteps: Int
    let totalDistanceWalked: Double
    let statusRawValue: String
    let createdAt: Date
    let updatedAt: Date
    var dayRoutes: [RestoredDayRouteData]
}

struct RestoredDayRouteData {
    let id: UUID
    let dayNumber: Int
    let date: Date
    let startLocationName: String
    let startLatitude: Double
    let startLongitude: Double
    let endLocationName: String
    let endLatitude: Double
    let endLongitude: Double
    let distance: Double
    let waypointsData: Data?
    let statusRawValue: String
    var journalEntry: RestoredJournalEntryData?
}

struct RestoredJournalEntryData {
    let id: UUID
    let text: String
    let createdAt: Date
    var photos: [RestoredPhotoData]
}

struct RestoredPhotoData {
    let id: UUID
    let photoData: Data
    let sortOrder: Int
    let createdAt: Date
}

// MARK: - Service

final class CloudKitBackupService {

    private let container: CKContainer
    private let database: CKDatabase

    // Record types
    private let journeyType = "Journey"
    private let dayRouteType = "DayRoute"
    private let journalEntryType = "JournalEntry"
    private let journalPhotoType = "JournalPhoto"
    private let metadataType = "BackupMetadata"

    init(containerIdentifier: String = "iCloud.com.sground.jangddanji") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    // MARK: - Account Check

    func checkAccountStatus() async throws {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw CloudKitBackupError.noICloudAccount
        }
    }

    // MARK: - Backup Status

    func checkBackupStatus() async throws -> BackupStatus {
        try await checkAccountStatus()

        var lastBackupDate: Date?
        var count = 0

        // 백업한 적 없으면 해당 레코드 타입이 CloudKit에 존재하지 않음 → 에러 대신 "백업 없음"으로 처리
        let epoch = Date(timeIntervalSince1970: 0)

        do {
            let metaQuery = CKQuery(recordType: metadataType, predicate: NSPredicate(format: "lastBackupDate >= %@", epoch as CVarArg))
            let (metaResults, _) = try await database.records(matching: metaQuery, resultsLimit: 1)
            lastBackupDate = metaResults.compactMap { try? $0.1.get() }.first?["lastBackupDate"] as? Date
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // 레코드 타입 없음 = 아직 백업 없음
        }

        do {
            let journeyQuery = CKQuery(recordType: journeyType, predicate: NSPredicate(format: "createdAt >= %@", epoch as CVarArg))
            let (journeyResults, _) = try await database.records(matching: journeyQuery, resultsLimit: 100)
            count = journeyResults.compactMap { try? $0.1.get() }.count
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // 레코드 타입 없음 = 아직 백업 없음
        }

        return BackupStatus(lastBackupDate: lastBackupDate, journeyCount: count)
    }

    // MARK: - Backup (Merge)

    func backup(
        journeys: [Journey],
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> MergeResult {
        try await checkAccountStatus()

        var result = MergeResult()
        let total = journeys.count
        var completed = 0

        // 1. 클라우드 현황 파악
        progressHandler(0, "클라우드 현황 확인 중...")
        let cloudMap = try await fetchCloudJourneyMap()

        // 2. 로컬 여정 순회 → 병합
        for journey in journeys {
            let idStr = journey.id.uuidString
            completed += 1
            let progress = Double(completed) / Double(max(total, 1))

            if let cloudRecord = cloudMap[idStr] {
                // 클라우드에 이미 존재 → updatedAt 비교
                let cloudUpdatedAt = cloudRecord["updatedAt"] as? Date ?? Date.distantPast
                if journey.updatedAt > cloudUpdatedAt {
                    // 로컬이 더 최신 → 갱신
                    progressHandler(progress, "'\(journey.title)' 업데이트 중...")
                    updateJourneyRecord(cloudRecord, with: journey)
                    try await database.save(cloudRecord)
                    try await deleteChildRecords(journeyRecordID: cloudRecord.recordID)
                    try await uploadChildRecords(journey: journey, journeyRecordID: cloudRecord.recordID)
                    result.updated += 1
                } else {
                    // 클라우드가 최신이거나 동일 → 스킵
                    progressHandler(progress, "'\(journey.title)' 변경 없음, 스킵")
                    result.skipped += 1
                }
            } else {
                // 클라우드에 없음 → 신규 업로드
                progressHandler(progress, "'\(journey.title)' 업로드 중...")
                let newRecord = makeJourneyRecord(journey)
                try await database.save(newRecord)
                try await uploadChildRecords(journey: journey, journeyRecordID: newRecord.recordID)
                result.uploaded += 1
            }
        }

        // 3. 메타데이터 갱신
        try await saveBackupMetadata()
        progressHandler(1.0, "백업 완료")
        return result
    }

    // MARK: - Restore

    func restore(
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> [RestoredJourneyData] {
        try await checkAccountStatus()

        progressHandler(0, "백업 데이터 확인 중...")

        // 1. Journey 가져오기 (같은 id 중 updatedAt이 가장 최신인 것만 유지)
        let allJourneyRecords = try await fetchAllRecords(ofType: journeyType)
        var journeyMap: [String: CKRecord] = [:]
        for record in allJourneyRecords {
            guard let id = record["id"] as? String else { continue }
            let existing = journeyMap[id]
            let existingDate = existing?["updatedAt"] as? Date ?? Date.distantPast
            let newDate = record["updatedAt"] as? Date ?? Date.distantPast
            if newDate > existingDate {
                journeyMap[id] = record
            }
        }
        let journeyRecords = Array(journeyMap.values)
        guard !journeyRecords.isEmpty else {
            throw CloudKitBackupError.restoreFailed("복원할 백업 데이터가 없습니다.")
        }

        let totalRecords = journeyRecords.count
        var completed = 0
        var restoredJourneys: [RestoredJourneyData] = []

        for journeyRecord in journeyRecords {
            completed += 1
            let title = journeyRecord["title"] as? String ?? ""
            progressHandler(Double(completed) / Double(totalRecords), "여정 '\(title)' 복원 중...")

            // 2. DayRoutes 가져오기
            let dayRouteRecords = try await fetchRelatedRecords(
                ofType: dayRouteType,
                referenceField: "journeyRef",
                parentRecordID: journeyRecord.recordID
            )

            var restoredDayRoutes: [RestoredDayRouteData] = []

            for dayRouteRecord in dayRouteRecords {
                // 3. JournalEntry 가져오기
                let entryRecords = try await fetchRelatedRecords(
                    ofType: journalEntryType,
                    referenceField: "dayRouteRef",
                    parentRecordID: dayRouteRecord.recordID
                )

                var restoredEntry: RestoredJournalEntryData?

                if let entryRecord = entryRecords.first {
                    // 4. Photos 가져오기
                    let photoRecords = try await fetchRelatedRecords(
                        ofType: journalPhotoType,
                        referenceField: "journalEntryRef",
                        parentRecordID: entryRecord.recordID
                    )

                    let restoredPhotos: [RestoredPhotoData] = photoRecords.compactMap { record in
                        guard let asset = record["photoAsset"] as? CKAsset,
                              let fileURL = asset.fileURL,
                              let data = try? Data(contentsOf: fileURL) else { return nil }
                        return RestoredPhotoData(
                            id: UUID(uuidString: record["id"] as? String ?? "") ?? UUID(),
                            photoData: data,
                            sortOrder: record["sortOrder"] as? Int ?? 0,
                            createdAt: record["createdAt"] as? Date ?? Date()
                        )
                    }

                    restoredEntry = RestoredJournalEntryData(
                        id: UUID(uuidString: entryRecord["id"] as? String ?? "") ?? UUID(),
                        text: entryRecord["text"] as? String ?? "",
                        createdAt: entryRecord["createdAt"] as? Date ?? Date(),
                        photos: restoredPhotos
                    )
                }

                restoredDayRoutes.append(RestoredDayRouteData(
                    id: UUID(uuidString: dayRouteRecord["id"] as? String ?? "") ?? UUID(),
                    dayNumber: dayRouteRecord["dayNumber"] as? Int ?? 0,
                    date: dayRouteRecord["date"] as? Date ?? Date(),
                    startLocationName: dayRouteRecord["startLocationName"] as? String ?? "",
                    startLatitude: dayRouteRecord["startLatitude"] as? Double ?? 0,
                    startLongitude: dayRouteRecord["startLongitude"] as? Double ?? 0,
                    endLocationName: dayRouteRecord["endLocationName"] as? String ?? "",
                    endLatitude: dayRouteRecord["endLatitude"] as? Double ?? 0,
                    endLongitude: dayRouteRecord["endLongitude"] as? Double ?? 0,
                    distance: dayRouteRecord["distance"] as? Double ?? 0,
                    waypointsData: (dayRouteRecord["waypointsData"] as? NSData).map { Data($0) },
                    statusRawValue: dayRouteRecord["statusRawValue"] as? String ?? "upcoming",
                    journalEntry: restoredEntry
                ))
            }

            restoredJourneys.append(RestoredJourneyData(
                id: UUID(uuidString: journeyRecord["id"] as? String ?? "") ?? UUID(),
                title: title,
                startLocationName: journeyRecord["startLocationName"] as? String ?? "",
                startLatitude: journeyRecord["startLatitude"] as? Double ?? 0,
                startLongitude: journeyRecord["startLongitude"] as? Double ?? 0,
                endLocationName: journeyRecord["endLocationName"] as? String ?? "",
                endLatitude: journeyRecord["endLatitude"] as? Double ?? 0,
                endLongitude: journeyRecord["endLongitude"] as? Double ?? 0,
                startDate: journeyRecord["startDate"] as? Date ?? Date(),
                endDate: journeyRecord["endDate"] as? Date ?? Date(),
                totalDistance: journeyRecord["totalDistance"] as? Double ?? 0,
                totalSteps: journeyRecord["totalSteps"] as? Int ?? 0,
                totalDistanceWalked: journeyRecord["totalDistanceWalked"] as? Double ?? 0,
                statusRawValue: journeyRecord["statusRawValue"] as? String ?? "planning",
                createdAt: journeyRecord["createdAt"] as? Date ?? Date(),
                updatedAt: journeyRecord["updatedAt"] as? Date ?? journeyRecord["createdAt"] as? Date ?? Date(),
                dayRoutes: restoredDayRoutes.sorted { $0.dayNumber < $1.dayNumber }
            ))
        }

        progressHandler(1.0, "복원 완료")
        return restoredJourneys
    }

    // MARK: - Delete All

    func deleteAllCloudData() async throws {
        let types = [journalPhotoType, journalEntryType, dayRouteType, journeyType, metadataType]
        for type in types {
            do {
                let records = try await fetchAllRecords(ofType: type)
                for record in records {
                    try await database.deleteRecord(withID: record.recordID)
                }
            } catch let ckError as CKError where ckError.code == .unknownItem {
                // 레코드 타입 없음 = 삭제할 것 없음, 계속 진행
            }
        }
    }

    // MARK: - Merge Helpers

    private func fetchCloudJourneyMap() async throws -> [String: CKRecord] {
        do {
            let records = try await fetchAllRecords(ofType: journeyType)
            // 같은 id의 레코드가 여러 개 있을 경우 updatedAt이 가장 최신인 것만 유지
            var map: [String: CKRecord] = [:]
            for record in records {
                guard let id = record["id"] as? String else { continue }
                let existing = map[id]
                let existingDate = existing?["updatedAt"] as? Date ?? Date.distantPast
                let newDate = record["updatedAt"] as? Date ?? Date.distantPast
                if newDate > existingDate {
                    map[id] = record
                }
            }
            return map
        } catch let ckError as CKError where ckError.code == .unknownItem {
            return [:]
        }
    }

    private func deleteChildRecords(journeyRecordID: CKRecord.ID) async throws {
        // DayRoute만 삭제하면 .deleteSelf reference로 JournalEntry, JournalPhoto 연쇄 삭제
        let dayRoutes = try await fetchRelatedRecords(
            ofType: dayRouteType,
            referenceField: "journeyRef",
            parentRecordID: journeyRecordID
        )
        for record in dayRoutes {
            try await database.deleteRecord(withID: record.recordID)
        }
    }

    private func uploadChildRecords(journey: Journey, journeyRecordID: CKRecord.ID) async throws {
        for dayRoute in journey.sortedDayRoutes {
            let dayRouteRecord = makeDayRouteRecord(dayRoute, journeyRecordID: journeyRecordID)
            try await database.save(dayRouteRecord)

            if let entry = dayRoute.journalEntry {
                let entryRecord = makeJournalEntryRecord(entry, dayRouteRecordID: dayRouteRecord.recordID)
                try await database.save(entryRecord)

                for photo in entry.sortedPhotos {
                    let photoRecord = makePhotoRecord(photo, entryRecordID: entryRecord.recordID)
                    try await database.save(photoRecord)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func countTotalItems(_ journeys: [Journey]) -> Int {
        var count = journeys.count
        for journey in journeys {
            count += journey.dayRoutes.count
            for dayRoute in journey.dayRoutes {
                if let entry = dayRoute.journalEntry {
                    count += 1
                    count += entry.photos.count
                }
            }
        }
        return count
    }

    private func makeJourneyRecord(_ journey: Journey) -> CKRecord {
        let record = CKRecord(recordType: journeyType)
        fillJourneyRecord(record, with: journey)
        return record
    }

    private func updateJourneyRecord(_ record: CKRecord, with journey: Journey) {
        fillJourneyRecord(record, with: journey)
    }

    private func fillJourneyRecord(_ record: CKRecord, with journey: Journey) {
        record["id"] = journey.id.uuidString
        record["title"] = journey.title
        record["startLocationName"] = journey.startLocationName
        record["startLatitude"] = journey.startLatitude
        record["startLongitude"] = journey.startLongitude
        record["endLocationName"] = journey.endLocationName
        record["endLatitude"] = journey.endLatitude
        record["endLongitude"] = journey.endLongitude
        record["startDate"] = journey.startDate
        record["endDate"] = journey.endDate
        record["totalDistance"] = journey.totalDistance
        record["totalSteps"] = journey.totalSteps
        record["totalDistanceWalked"] = journey.totalDistanceWalked
        record["statusRawValue"] = journey.statusRawValue
        record["createdAt"] = journey.createdAt
        record["updatedAt"] = journey.updatedAt
    }

    private func makeDayRouteRecord(_ dayRoute: DayRoute, journeyRecordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: dayRouteType)
        record["id"] = dayRoute.id.uuidString
        record["dayNumber"] = dayRoute.dayNumber
        record["date"] = dayRoute.date
        record["startLocationName"] = dayRoute.startLocationName
        record["startLatitude"] = dayRoute.startLatitude
        record["startLongitude"] = dayRoute.startLongitude
        record["endLocationName"] = dayRoute.endLocationName
        record["endLatitude"] = dayRoute.endLatitude
        record["endLongitude"] = dayRoute.endLongitude
        record["distance"] = dayRoute.distance
        record["statusRawValue"] = dayRoute.statusRawValue
        record["waypointsData"] = dayRoute.waypointsData.map { NSData(data: $0) }
        record["journeyRef"] = CKRecord.Reference(recordID: journeyRecordID, action: .deleteSelf)
        return record
    }

    private func makeJournalEntryRecord(_ entry: JournalEntry, dayRouteRecordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: journalEntryType)
        record["id"] = entry.id.uuidString
        record["text"] = entry.text
        record["createdAt"] = entry.createdAt
        record["dayRouteRef"] = CKRecord.Reference(recordID: dayRouteRecordID, action: .deleteSelf)
        return record
    }

    private func makePhotoRecord(_ photo: JournalPhoto, entryRecordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: journalPhotoType)
        record["id"] = photo.id.uuidString
        record["sortOrder"] = photo.sortOrder
        record["createdAt"] = photo.createdAt
        record["journalEntryRef"] = CKRecord.Reference(recordID: entryRecordID, action: .deleteSelf)

        // CKAsset으로 사진 저장
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try? photo.photoData.write(to: tempURL)
        record["photoAsset"] = CKAsset(fileURL: tempURL)

        return record
    }

    private func fetchAllRecords(ofType type: String) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let epoch = Date(timeIntervalSince1970: 0)

        // 타입별로 Queryable한 날짜 필드 사용
        let dateField: String
        switch type {
        case metadataType:  dateField = "lastBackupDate"
        case dayRouteType:  dateField = "date"          // DayRoute는 createdAt 없음, date 사용
        default:            dateField = "createdAt"
        }
        let query = CKQuery(recordType: type, predicate: NSPredicate(format: "%K >= %@", dateField, epoch as CVarArg))
        var cursor: CKQueryOperation.Cursor?

        do {
            let (results, nextCursor) = try await database.records(matching: query, resultsLimit: 200)
            allRecords.append(contentsOf: results.compactMap { try? $0.1.get() })
            cursor = nextCursor
        } catch let ckError as CKError {
            if isRecordTypeNotFound(ckError) { return [] }
            throw ckError
        }

        while let currentCursor = cursor {
            let (moreResults, moreCursor) = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: 200)
            allRecords.append(contentsOf: moreResults.compactMap { try? $0.1.get() })
            cursor = moreCursor
        }

        return allRecords
    }

    private func fetchRelatedRecords(
        ofType type: String,
        referenceField: String,
        parentRecordID: CKRecord.ID
    ) async throws -> [CKRecord] {
        let reference = CKRecord.Reference(recordID: parentRecordID, action: .none)
        let predicate = NSPredicate(format: "%K == %@", referenceField, reference)
        let query = CKQuery(recordType: type, predicate: predicate)

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        do {
            let (results, nextCursor) = try await database.records(matching: query, resultsLimit: 200)
            allRecords.append(contentsOf: results.compactMap { try? $0.1.get() })
            cursor = nextCursor
        } catch let ckError as CKError {
            if isRecordTypeNotFound(ckError) { return [] }
            throw ckError
        }

        while let currentCursor = cursor {
            let (moreResults, moreCursor) = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: 200)
            allRecords.append(contentsOf: moreResults.compactMap { try? $0.1.get() })
            cursor = moreCursor
        }

        return allRecords
    }

    /// "Did not find record type" 에러 여부 판별 (코드가 버전마다 다를 수 있어 메시지도 함께 확인)
    private func isRecordTypeNotFound(_ error: CKError) -> Bool {
        if error.code == .unknownItem { return true }
        let desc = error.localizedDescription
        return desc.contains("Did not find record type") || desc.contains("record type")
    }

    private func saveBackupMetadata() async throws {
        // 기존 메타데이터 삭제 (처음 백업 시엔 타입이 없을 수 있으므로 무시)
        do {
            let existing = try await fetchAllRecords(ofType: metadataType)
            for record in existing {
                try await database.deleteRecord(withID: record.recordID)
            }
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // 아직 BackupMetadata 타입 없음 = 삭제할 것 없음
        }

        let record = CKRecord(recordType: metadataType)
        record["lastBackupDate"] = Date()
        try await database.save(record)
    }
}
