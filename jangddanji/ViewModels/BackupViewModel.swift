import Foundation
import SwiftData

@Observable
final class BackupViewModel {

    var isBackingUp = false
    var isRestoring = false
    var isCheckingStatus = false
    var progress: Double = 0
    var progressMessage: String = ""
    var errorMessage: String?
    var successMessage: String?
    var lastBackupDate: Date?
    var cloudJourneyCount: Int = 0
    var showRestoreConfirm = false
    var showDeleteConfirm = false
    var isDeleting = false
    var iCloudAvailable = true

    private let backupService = CloudKitBackupService()

    // MARK: - Check Status

    func checkBackupStatus() async {
        isCheckingStatus = true
        errorMessage = nil

        do {
            let status = try await backupService.checkBackupStatus()
            lastBackupDate = status.lastBackupDate
            cloudJourneyCount = status.journeyCount
            iCloudAvailable = true
        } catch let error as CloudKitBackupError {
            if case .noICloudAccount = error {
                iCloudAvailable = false
            }
            errorMessage = error.errorDescription
        } catch let ckError as NSError where ckError.domain == "CKErrorDomain" {
            // CloudKit 스키마 미설정 (인덱스 없음 등) → 백업 없음으로 간주
            lastBackupDate = nil
            cloudJourneyCount = 0
            iCloudAvailable = true
        } catch {
            errorMessage = "상태 확인 실패: \(error.localizedDescription)"
        }

        isCheckingStatus = false
    }

    // MARK: - Backup

    func backupAllData(context: ModelContext) async {
        isBackingUp = true
        progress = 0
        progressMessage = "백업 준비 중..."
        errorMessage = nil
        successMessage = nil

        do {
            let descriptor = FetchDescriptor<Journey>()
            let journeys = try context.fetch(descriptor)

            guard !journeys.isEmpty else {
                errorMessage = "백업할 여정 데이터가 없습니다."
                isBackingUp = false
                return
            }

            let result = try await backupService.backup(journeys: journeys) { [weak self] progress, message in
                Task { @MainActor in
                    self?.progress = progress
                    self?.progressMessage = message
                }
            }

            var parts: [String] = []
            if result.uploaded > 0 { parts.append("신규 \(result.uploaded)개") }
            if result.updated > 0  { parts.append("업데이트 \(result.updated)개") }
            if result.skipped > 0  { parts.append("변경없음 \(result.skipped)개") }
            successMessage = parts.isEmpty ? "백업할 변경사항이 없습니다." : parts.joined(separator: ", ") + " 백업 완료"
            await checkBackupStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isBackingUp = false
    }

    // MARK: - Restore

    func restoreAllData(context: ModelContext) async {
        isRestoring = true
        progress = 0
        progressMessage = "복원 준비 중..."
        errorMessage = nil
        successMessage = nil

        do {
            let restoredJourneys = try await backupService.restore { [weak self] progress, message in
                Task { @MainActor in
                    self?.progress = progress
                    self?.progressMessage = message
                }
            }

            // 기존 로컬 데이터 삭제
            progressMessage = "로컬 데이터 정리 중..."
            let existingJourneys = try context.fetch(FetchDescriptor<Journey>())
            for journey in existingJourneys {
                context.delete(journey)
            }
            try context.save()

            // 복원 데이터 삽입
            progressMessage = "데이터 저장 중..."
            for journeyData in restoredJourneys {
                let journey = Journey(
                    title: journeyData.title,
                    startLocationName: journeyData.startLocationName,
                    startLatitude: journeyData.startLatitude,
                    startLongitude: journeyData.startLongitude,
                    endLocationName: journeyData.endLocationName,
                    endLatitude: journeyData.endLatitude,
                    endLongitude: journeyData.endLongitude,
                    startDate: journeyData.startDate,
                    endDate: journeyData.endDate,
                    totalDistance: journeyData.totalDistance
                )
                journey.totalSteps = journeyData.totalSteps
                journey.totalDistanceWalked = journeyData.totalDistanceWalked
                journey.statusRawValue = journeyData.statusRawValue
                journey.updatedAt = journeyData.updatedAt
                context.insert(journey)

                for dayRouteData in journeyData.dayRoutes {
                    let dayRoute = DayRoute(
                        dayNumber: dayRouteData.dayNumber,
                        date: dayRouteData.date,
                        startLocationName: dayRouteData.startLocationName,
                        startLatitude: dayRouteData.startLatitude,
                        startLongitude: dayRouteData.startLongitude,
                        endLocationName: dayRouteData.endLocationName,
                        endLatitude: dayRouteData.endLatitude,
                        endLongitude: dayRouteData.endLongitude,
                        distance: dayRouteData.distance
                    )
                    dayRoute.statusRawValue = dayRouteData.statusRawValue
                    dayRoute.waypointsData = dayRouteData.waypointsData
                    dayRoute.journey = journey
                    context.insert(dayRoute)

                    if let entryData = dayRouteData.journalEntry {
                        let entry = JournalEntry(text: entryData.text)
                        entry.dayRoute = dayRoute
                        context.insert(entry)

                        for photoData in entryData.photos {
                            let photo = JournalPhoto(photoData: photoData.photoData, sortOrder: photoData.sortOrder)
                            photo.journalEntry = entry
                            context.insert(photo)
                        }
                    }
                }
            }

            try context.save()
            successMessage = "\(restoredJourneys.count)개의 여정이 복원되었습니다."
        } catch {
            errorMessage = error.localizedDescription
        }

        isRestoring = false
    }

    // MARK: - Delete

    func deleteAllCloudData() async {
        isDeleting = true
        errorMessage = nil
        successMessage = nil

        do {
            try await backupService.deleteAllCloudData()
            successMessage = "iCloud 백업 데이터가 모두 삭제되었습니다."
            await checkBackupStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isDeleting = false
    }
}
