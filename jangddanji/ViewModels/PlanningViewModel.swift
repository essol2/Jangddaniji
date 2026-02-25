import Foundation
import SwiftData
import CoreLocation

@Observable
final class PlanningViewModel {
    enum PlanningMode {
        case byDuration   // 여정 기간으로 계획하기
        case byDistance    // 하루 목표 거리로 계획하기
    }

    enum Step: Hashable, CaseIterable {
        case startLocation
        case endLocation
        case modeSelection
        case schedule        // Mode A (byDuration) 전용
        case distance        // Mode B (byDistance) 전용
        case confirm

        var title: String {
            switch self {
            case .startLocation: return "출발지"
            case .endLocation: return "목적지"
            case .modeSelection: return "계획 방식"
            case .schedule: return "여정 기간"
            case .distance: return "목표 거리"
            case .confirm: return "확인"
            }
        }
    }

    var currentStep: Step = .startLocation
    var planningMode: PlanningMode?
    var startLocation: LocationResult?
    var endLocation: LocationResult?
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 13, to: Date()) ?? Date()
    var dailyDistanceKm: Double = 30
    var routeResult: RouteResult?
    var daySegments: [DaySegment] = []
    var segmentNames: [(start: String, end: String)] = []
    var isCalculating = false
    var errorMessage: String?

    private let locationService: LocationSearchServiceProtocol
    private let routeService: RouteCalculationServiceProtocol
    private let splittingService: RouteSplittingService

    init(
        locationService: LocationSearchServiceProtocol = AppleLocationSearchService(),
        routeService: RouteCalculationServiceProtocol = AppleRouteCalculationService(),
        splittingService: RouteSplittingService = RouteSplittingService()
    ) {
        self.locationService = locationService
        self.routeService = routeService
        self.splittingService = splittingService
    }

    // MARK: - 모드에 따른 활성 단계

    var activeSteps: [Step] {
        var steps: [Step] = [.startLocation, .endLocation, .modeSelection]
        switch planningMode {
        case .byDuration:
            steps.append(.schedule)
        case .byDistance:
            steps.append(.distance)
        case nil:
            break
        }
        steps.append(.confirm)
        return steps
    }

    // MARK: - 계산 프로퍼티

    var numberOfDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days + 1, 1)
    }

    var canGoNext: Bool {
        switch currentStep {
        case .startLocation: return startLocation != nil
        case .endLocation: return endLocation != nil
        case .modeSelection: return planningMode != nil
        case .schedule: return endDate > startDate
        case .distance: return dailyDistanceKm >= 5
        case .confirm: return !daySegments.isEmpty
        }
    }

    var estimatedDailyDistanceKm: Double? {
        guard let routeResult else { return nil }
        return (routeResult.totalDistance / 1000) / Double(numberOfDays)
    }

    // MARK: - 네비게이션

    func goNext() {
        guard let idx = activeSteps.firstIndex(of: currentStep),
              idx + 1 < activeSteps.count else { return }
        currentStep = activeSteps[idx + 1]
    }

    func goBack() {
        guard let idx = activeSteps.firstIndex(of: currentStep),
              idx > 0 else { return }
        // 이전 단계로 돌아가면 계산 결과 초기화 (다시 confirm에 올 때 재계산)
        routeResult = nil
        daySegments = []
        segmentNames = []
        errorMessage = nil
        currentStep = activeSteps[idx - 1]
        // 모드 선택 단계로 돌아가면 모드 초기화
        if currentStep == .modeSelection {
            planningMode = nil
        }
    }

    // MARK: - 경로 계산

    func calculateRoute() async {
        guard let start = startLocation, let end = endLocation else { return }

        isCalculating = true
        errorMessage = nil

        do {
            let result = try await routeService.calculateWalkingRoute(
                from: start.coordinate,
                to: end.coordinate
            )
            routeResult = result

            // 모드에 따라 일수 결정
            let days: Int
            switch planningMode {
            case .byDuration, .none:
                days = numberOfDays  // 날짜 범위에서 계산 (기존 로직)
            case .byDistance:
                days = max(Int(ceil(result.totalDistance / (dailyDistanceKm * 1000))), 1)
                // Mode B: endDate 자동 계산
                endDate = Calendar.current.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
            }

            let segments = splittingService.splitRoute(
                polylinePoints: result.polylinePoints,
                totalDistance: result.totalDistance,
                numberOfDays: days
            )
            daySegments = segments

            // Reverse geocode segment endpoints
            var names: [(start: String, end: String)] = []
            for segment in segments {
                let startName: String
                let endName: String

                if segment.dayNumber == 1 {
                    startName = start.name
                } else {
                    startName = await splittingService.reverseGeocode(coordinate: segment.startCoordinate)
                    try? await Task.sleep(for: .milliseconds(300))
                }

                if segment.dayNumber == segments.count {
                    endName = end.name
                } else {
                    endName = await splittingService.reverseGeocode(coordinate: segment.endCoordinate)
                    try? await Task.sleep(for: .milliseconds(300))
                }

                names.append((start: startName, end: endName))
            }
            segmentNames = names
        } catch {
            errorMessage = error.localizedDescription
        }

        isCalculating = false
    }

    // MARK: - 여정 생성

    func createJourney(in context: ModelContext) -> Journey {
        let title = "\(startLocation?.name ?? "") → \(endLocation?.name ?? "")"
        let journey = Journey(
            title: title,
            startLocationName: startLocation?.name ?? "",
            startLatitude: startLocation?.latitude ?? 0,
            startLongitude: startLocation?.longitude ?? 0,
            endLocationName: endLocation?.name ?? "",
            endLatitude: endLocation?.latitude ?? 0,
            endLongitude: endLocation?.longitude ?? 0,
            startDate: startDate,
            endDate: endDate,
            totalDistance: routeResult?.totalDistance ?? 0
        )
        journey.status = .active
        context.insert(journey)

        for (index, segment) in daySegments.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? startDate
            let names = index < segmentNames.count ? segmentNames[index] : (start: "출발", end: "도착")
            let dayRoute = DayRoute(
                dayNumber: segment.dayNumber,
                date: date,
                startLocationName: names.start,
                startLatitude: segment.startCoordinate.latitude,
                startLongitude: segment.startCoordinate.longitude,
                endLocationName: names.end,
                endLatitude: segment.endCoordinate.latitude,
                endLongitude: segment.endCoordinate.longitude,
                distance: segment.distance
            )

            if Calendar.current.isDateInToday(date) {
                dayRoute.status = .today
            }

            dayRoute.journey = journey
            context.insert(dayRoute)
        }

        try? context.save()
        return journey
    }
}
