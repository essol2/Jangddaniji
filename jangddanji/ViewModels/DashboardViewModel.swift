import Foundation
import SwiftData
import CoreLocation

@Observable
final class DashboardViewModel {
    private(set) var journey: Journey
    private let mapService = ExternalMapService()

    init(journey: Journey) {
        self.journey = journey
    }

    var totalCount: Int {
        journey.dayRoutes.count
    }

    var completedCount: Int {
        journey.dayRoutes.filter { $0.status == .completed }.count
    }

    var completionPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int(Double(completedCount) / Double(totalCount) * 100)
    }

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var todayRoute: DayRoute? {
        let today = Calendar.current.startOfDay(for: Date())
        return journey.sortedDayRoutes.first {
            Calendar.current.startOfDay(for: $0.date) == today
        }
    }

    var isTodayCompleted: Bool {
        todayRoute?.status == .completed
    }

    var remainingDistance: Double {
        journey.dayRoutes
            .filter { $0.status == .upcoming || $0.status == .today }
            .reduce(0) { $0 + $1.distance }
    }

    var availableMapApps: [MapApp] {
        mapService.availableApps()
    }

    func updateStatuses(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        for dayRoute in journey.dayRoutes {
            guard dayRoute.status != .completed && dayRoute.status != .skipped else { continue }
            let routeDay = Calendar.current.startOfDay(for: dayRoute.date)
            if routeDay == today {
                if dayRoute.status != .today { dayRoute.status = .today }
            } else if routeDay > today {
                if dayRoute.status != .upcoming { dayRoute.status = .upcoming }
            }
        }
        try? context.save()
    }

    func markCompleted(context: ModelContext, totalSteps: Int = 0, totalDistanceKm: Double = 0) {
        guard let todayRoute else { return }
        todayRoute.status = .completed

        // Live Activity 종료
        LiveActivityManager.shared.endActivity(isCompleted: true)

        if journey.dayRoutes.allSatisfy({ $0.status == .completed }) {
            journey.totalSteps = totalSteps
            journey.totalDistanceWalked = totalDistanceKm
            journey.status = .completed
        }

        try? context.save()
    }

    func undoCompleted(context: ModelContext) {
        guard let todayRoute, todayRoute.status == .completed else { return }
        todayRoute.status = .today
        try? context.save()

        // Live Activity 재시작
        LiveActivityManager.shared.startActivity(
            journeyTitle: journey.title,
            dayNumber: todayRoute.dayNumber,
            startLocationName: todayRoute.startLocationName,
            endLocationName: todayRoute.endLocationName,
            totalDistanceMeters: todayRoute.distance,
            todaySteps: 0,
            todayDistanceKm: 0
        )
    }

    @available(iOS, deprecated: 26.0)
    func openDirections(for dayRoute: DayRoute, with app: MapApp) {
        let from = CLLocationCoordinate2D(latitude: dayRoute.startLatitude, longitude: dayRoute.startLongitude)
        let to = CLLocationCoordinate2D(latitude: dayRoute.endLatitude, longitude: dayRoute.endLongitude)
        mapService.openDirections(
            app: app,
            from: from,
            fromName: dayRoute.startLocationName,
            to: to,
            toName: dayRoute.endLocationName
        )
    }
}
