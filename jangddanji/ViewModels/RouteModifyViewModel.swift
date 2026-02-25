import Foundation
import SwiftData
import CoreLocation

@Observable
final class RouteModifyViewModel {
    private(set) var dayRoute: DayRoute
    private(set) var journey: Journey

    var searchResults: [LocationResult] = []
    var newEndLocationName: String
    var newEndLatitude: Double
    var newEndLongitude: Double

    var isCalculating = false
    var errorMessage: String?

    private let locationService: LocationSearchServiceProtocol
    private let routeService: RouteCalculationServiceProtocol
    private let splittingService: RouteSplittingService

    init(
        dayRoute: DayRoute,
        locationService: LocationSearchServiceProtocol = AppleLocationSearchService(),
        routeService: RouteCalculationServiceProtocol = AppleRouteCalculationService(),
        splittingService: RouteSplittingService = RouteSplittingService()
    ) {
        self.dayRoute = dayRoute
        self.journey = dayRoute.journey!
        self.newEndLocationName = dayRoute.endLocationName
        self.newEndLatitude = dayRoute.endLatitude
        self.newEndLongitude = dayRoute.endLongitude
        self.locationService = locationService
        self.routeService = routeService
        self.splittingService = splittingService
    }

    var initialRemainingDays: Int {
        let total = dayRoute.journey?.sortedDayRoutes.count ?? dayRoute.dayNumber
        return max(total - dayRoute.dayNumber, 1)
    }

    @available(iOS, deprecated: 26.0)
    func searchLocations(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await locationService.search(query: query)
        } catch {
            searchResults = []
        }
    }

    func selectLocation(_ result: LocationResult) {
        newEndLocationName = result.name
        newEndLatitude = result.latitude
        newEndLongitude = result.longitude
        searchResults = []
    }

    @available(iOS, deprecated: 26.0)
    func recalculate(remainingDaysCount: Int, context: ModelContext) async {
        isCalculating = true
        errorMessage = nil
        defer { isCalculating = false }

        do {
            let startCoord = CLLocationCoordinate2D(latitude: newEndLatitude, longitude: newEndLongitude)
            let endCoord = CLLocationCoordinate2D(latitude: journey.endLatitude, longitude: journey.endLongitude)

            let routeResult = try await routeService.calculateWalkingRoute(from: startCoord, to: endCoord)
            let segments = splittingService.splitRoute(
                polylinePoints: routeResult.polylinePoints,
                totalDistance: routeResult.totalDistance,
                numberOfDays: remainingDaysCount
            )

            // 현재 구간의 거리도 재계산 (출발지 → 새 도착지)
            let todayStart = CLLocationCoordinate2D(latitude: dayRoute.startLatitude, longitude: dayRoute.startLongitude)
            let todayEnd = CLLocationCoordinate2D(latitude: newEndLatitude, longitude: newEndLongitude)
            let todayRoute = try await routeService.calculateWalkingRoute(from: todayStart, to: todayEnd)

            // 이후 DayRoute 삭제
            let toDelete = journey.sortedDayRoutes.filter { $0.dayNumber > dayRoute.dayNumber }
            for route in toDelete { context.delete(route) }

            // 현재 날의 도착지 + 거리 업데이트
            dayRoute.endLocationName = newEndLocationName
            dayRoute.endLatitude = newEndLatitude
            dayRoute.endLongitude = newEndLongitude
            dayRoute.distance = todayRoute.totalDistance

            // 새 DayRoute 생성
            for (index, segment) in segments.enumerated() {
                let newDayNumber = dayRoute.dayNumber + index + 1
                let date = Calendar.current.date(byAdding: .day, value: index + 1, to: dayRoute.date) ?? dayRoute.date

                let startName: String
                if index == 0 {
                    startName = newEndLocationName
                } else {
                    startName = await splittingService.reverseGeocode(coordinate: segment.startCoordinate)
                    try? await Task.sleep(for: .milliseconds(300))
                }

                let endName: String
                if index == segments.count - 1 {
                    endName = journey.endLocationName
                } else {
                    endName = await splittingService.reverseGeocode(coordinate: segment.endCoordinate)
                    try? await Task.sleep(for: .milliseconds(300))
                }

                let newRoute = DayRoute(
                    dayNumber: newDayNumber,
                    date: date,
                    startLocationName: startName,
                    startLatitude: segment.startCoordinate.latitude,
                    startLongitude: segment.startCoordinate.longitude,
                    endLocationName: endName,
                    endLatitude: segment.endCoordinate.latitude,
                    endLongitude: segment.endCoordinate.longitude,
                    distance: segment.distance
                )

                if Calendar.current.isDateInToday(date) { newRoute.status = .today }
                newRoute.journey = journey
                context.insert(newRoute)
            }

            if let lastDate = Calendar.current.date(byAdding: .day, value: remainingDaysCount, to: dayRoute.date) {
                journey.endDate = lastDate
            }

            try? context.save()
        } catch {
            errorMessage = "경로 계산 실패: \(error.localizedDescription)"
        }
    }
}
