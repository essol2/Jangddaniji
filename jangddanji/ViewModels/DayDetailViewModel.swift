import Foundation
import SwiftData
import CoreLocation
import UIKit

@Observable
final class DayDetailViewModel {
    private(set) var dayRoute: DayRoute
    private let mapService = ExternalMapService()
    private var saveTask: Task<Void, Never>?

    init(dayRoute: DayRoute) {
        self.dayRoute = dayRoute
    }

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: dayRoute.startLatitude, longitude: dayRoute.startLongitude)
    }

    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: dayRoute.endLatitude, longitude: dayRoute.endLongitude)
    }

    var waypoints: [WaypointCoordinate] {
        dayRoute.waypointCoordinates
    }

    var initialText: String {
        dayRoute.journalEntry?.text ?? ""
    }

    // MARK: - Photo accessors

    var initialPhotos: [Data] {
        dayRoute.journalEntry?.sortedPhotos.map(\.photoData) ?? []
    }

    var availableMapApps: [MapApp] {
        mapService.availableApps()
    }

    // MARK: - Journal text save (텍스트와 사진을 독립적으로 저장)

    func scheduleSaveText(_ text: String, context: ModelContext) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self.saveJournalText(text, context: context)
        }
    }

    func saveJournalText(_ text: String, context: ModelContext) {
        ensureJournalEntry(context: context)
        dayRoute.journalEntry?.text = text
        try? context.save()
    }

    // MARK: - Photo management

    func addPhotos(_ photosData: [Data], context: ModelContext) {
        ensureJournalEntry(context: context)
        guard let entry = dayRoute.journalEntry else { return }
        let currentMaxOrder = entry.photos.map(\.sortOrder).max() ?? -1
        for (index, data) in photosData.enumerated() {
            let photo = JournalPhoto(photoData: data, sortOrder: currentMaxOrder + 1 + index)
            photo.journalEntry = entry
            entry.photos.append(photo)
            context.insert(photo)
        }
        try? context.save()
    }

    func deletePhoto(_ photo: JournalPhoto, context: ModelContext) {
        context.delete(photo)
        try? context.save()
    }

    func reorderPhotos(_ newOrder: [Data], context: ModelContext) {
        guard let entry = dayRoute.journalEntry else { return }
        let sorted = entry.sortedPhotos
        // newOrder의 Data 순서에 맞춰 sortOrder를 재설정
        for (newIndex, data) in newOrder.enumerated() {
            if let photo = sorted.first(where: { $0.photoData == data }) {
                photo.sortOrder = newIndex
            }
        }
        try? context.save()
    }

    private func ensureJournalEntry(context: ModelContext) {
        guard dayRoute.journalEntry == nil else { return }
        let entry = JournalEntry(text: "")
        entry.dayRoute = dayRoute
        dayRoute.journalEntry = entry
        context.insert(entry)
    }

    var isCompleted: Bool {
        dayRoute.status == .completed
    }

    var isTodayRoute: Bool {
        Calendar.current.isDateInToday(dayRoute.date)
    }

    // DEBUG: 모든 날짜에서 완료 가능 (배포 시 dayRoute.status == .today 로 변경)
    var canComplete: Bool {
        dayRoute.status != .completed
    }

    var isLastSegment: Bool {
        guard let journey = dayRoute.journey else { return false }
        let incomplete = journey.dayRoutes.filter { $0.status != .completed }
        return incomplete.count == 1 && incomplete.first?.id == dayRoute.id
    }

    func markCompleted(context: ModelContext, totalSteps: Int = 0, totalDistanceKm: Double = 0) {
        dayRoute.status = .completed

        // Live Activity 종료
        LiveActivityManager.shared.endActivity(isCompleted: true)

        if let journey = dayRoute.journey {
            if journey.dayRoutes.allSatisfy({ $0.status == .completed }) {
                journey.totalSteps = totalSteps
                journey.totalDistanceWalked = totalDistanceKm
                journey.status = .completed
            }
        }

        try? context.save()
    }

    func undoCompleted(context: ModelContext) {
        guard dayRoute.status == .completed else { return }
        // DEBUG: 날짜에 맞는 상태로 복원 (배포 시 .today 고정으로 변경)
        let today = Calendar.current.startOfDay(for: Date())
        let routeDay = Calendar.current.startOfDay(for: dayRoute.date)
        if routeDay == today {
            dayRoute.status = .today
        } else if routeDay > today {
            dayRoute.status = .upcoming
        } else {
            dayRoute.status = .today // 과거 날짜도 일단 today로
        }
        try? context.save()

        // Live Activity 재시작 (오늘 구간인 경우)
        if let journey = dayRoute.journey, Calendar.current.isDateInToday(dayRoute.date) {
            LiveActivityManager.shared.startActivity(
                journeyTitle: journey.title,
                dayNumber: dayRoute.dayNumber,
                startLocationName: dayRoute.startLocationName,
                endLocationName: dayRoute.endLocationName,
                totalDistanceMeters: dayRoute.distance,
                todaySteps: 0,
                todayDistanceKm: 0
            )
        }
    }

    @available(iOS, deprecated: 26.0)
    func openDirections(with app: MapApp) {
        mapService.openDirections(
            app: app,
            from: startCoordinate,
            fromName: dayRoute.startLocationName,
            to: endCoordinate,
            toName: dayRoute.endLocationName,
            waypoints: waypoints
        )
    }

    static func compressImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let size = image.size
        let scale = maxDimension / max(size.width, size.height)
        let targetSize = scale < 1
            ? CGSize(width: size.width * scale, height: size.height * scale)
            : size
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
