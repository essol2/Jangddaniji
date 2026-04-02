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

        let metaQuery = CKQuery(recordType: metadataType, predicate: NSPredicate(value: true))
        let (metaResults, _) = try await database.records(matching: metaQuery, resultsLimit: 1)
        let lastBackupDate = metaResults.compactMap { try? $0.1.get() }.first?["lastBackupDate"] as? Date

        let journeyQuery = CKQuery(recordType: journeyType, predicate: NSPredicate(value: true))
        let (journeyResults, _) = try await database.records(matching: journeyQuery, resultsLimit: 100)
        let count = journeyResults.compactMap { try? $0.1.get() }.count

        return BackupStatus(lastBackupDate: lastBackupDate, journeyCount: count)
    }

    // MARK: - Backup

    func backup(
        journeys: [Journey],
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        try await checkAccountStatus()

        let totalItems = countTotalItems(journeys)
        var completed = 0

        func updateProgress(_ message: String) {
            completed += 1
            progressHandler(Double(completed) / Double(max(totalItems, 1)), message)
        }

        // 1. 기존 클라우드 데이터 삭제
        progressHandler(0, "기존 백업 데이터 정리 중...")
        try await deleteAllCloudData()

        // 2. Journey 업로드
        for journey in journeys {
            let journeyRecord = makeJourneyRecord(journey)
            try await database.save(journeyRecord)
            updateProgress("여정 '\(journey.title)' 업로드 중...")

            // 3. DayRoute 업로드
            for dayRoute in journey.sortedDayRoutes {
                let dayRouteRecord = makeDayRouteRecord(dayRoute, journeyRecordID: journeyRecord.recordID)
                try await database.save(dayRouteRecord)
                updateProgress("\(dayRoute.dayNumber)일차 경로 업로드 중...")

                // 4. JournalEntry 업로드
                if let entry = dayRoute.journalEntry {
                    let entryRecord = makeJournalEntryRecord(entry, dayRouteRecordID: dayRouteRecord.recordID)
                    try await database.save(entryRecord)
                    updateProgress("일지 업로드 중...")

                    // 5. Photos 업로드
                    for photo in entry.sortedPhotos {
                        let photoRecord = makePhotoRecord(photo, entryRecordID: entryRecord.recordID)
                        try await database.save(photoRecord)
                        updateProgress("사진 업로드 중...")
                    }
                }
            }
        }

        // 6. 메타데이터 저장
        try await saveBackupMetadata()
        progressHandler(1.0, "백업 완료")
    }

    // MARK: - Restore

    func restore(
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> [RestoredJourneyData] {
        try await checkAccountStatus()

        progressHandler(0, "백업 데이터 확인 중...")

        // 1. Journey 가져오기
        let journeyRecords = try await fetchAllRecords(ofType: journeyType)
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
            let records = try await fetchAllRecords(ofType: type)
            for record in records {
                try await database.deleteRecord(withID: record.recordID)
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
        return record
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
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var cursor: CKQueryOperation.Cursor?

        let (results, nextCursor) = try await database.records(matching: query, resultsLimit: 200)
        allRecords.append(contentsOf: results.compactMap { try? $0.1.get() })
        cursor = nextCursor

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

        let (results, nextCursor) = try await database.records(matching: query, resultsLimit: 200)
        allRecords.append(contentsOf: results.compactMap { try? $0.1.get() })
        cursor = nextCursor

        while let currentCursor = cursor {
            let (moreResults, moreCursor) = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: 200)
            allRecords.append(contentsOf: moreResults.compactMap { try? $0.1.get() })
            cursor = moreCursor
        }

        return allRecords
    }

    private func saveBackupMetadata() async throws {
        // 기존 메타데이터 삭제
        let existing = try await fetchAllRecords(ofType: metadataType)
        for record in existing {
            try await database.deleteRecord(withID: record.recordID)
        }

        let record = CKRecord(recordType: metadataType)
        record["lastBackupDate"] = Date()
        try await database.save(record)
    }
}
