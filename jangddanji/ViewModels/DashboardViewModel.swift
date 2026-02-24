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

    var completionPercentage: Int {
        let total = journey.dayRoutes.count
        guard total > 0 else { return 0 }
        let completed = journey.dayRoutes.filter { $0.status == .completed }.count
        return Int(Double(completed) / Double(total) * 100)
    }

    var completionRate: Double {
        let total = journey.dayRoutes.count
        guard total > 0 else { return 0 }
        let completed = journey.dayRoutes.filter { $0.status == .completed }.count
        return Double(completed) / Double(total)
    }

    var todayRoute: DayRoute? {
        journey.sortedDayRoutes.first { $0.status == .today }
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

    func markCompleted(context: ModelContext) {
        guard let todayRoute else { return }
        todayRoute.status = .completed

        if let nextRoute = journey.sortedDayRoutes.first(where: { $0.dayNumber == todayRoute.dayNumber + 1 }) {
            nextRoute.status = .today
        }

        if journey.dayRoutes.allSatisfy({ $0.status == .completed }) {
            journey.status = .completed
        }

        try? context.save()
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
