import Foundation
import SwiftData
import CoreLocation

@Observable
final class PlanningViewModel {
    enum PlanningMode {
        case byDuration   // 여정 기간으로 계획하기
        case byDistance    // 하루 목표 거리로 계획하기
    }

    enum RouteSource {
        case manual        // 직접 입력
        case presetRoute   // 유명 경로 불러오기
    }

    enum SplittingStrategy {
        case byCourse       // 코스별로 걷기
        case equalDistance   // 날짜/거리로 나누기
    }

    enum Step: Hashable, CaseIterable {
        case routeSource
        case startLocation
        case endLocation
        case waypoints
        case presetRoute
        case modeSelection
        case schedule        // Mode A (byDuration) 전용
        case distance        // Mode B (byDistance) 전용
        case confirm

        var title: String {
            switch self {
            case .routeSource: return "경로 입력"
            case .startLocation: return "출발지"
            case .endLocation: return "목적지"
            case .waypoints: return "경유지"
            case .presetRoute: return "경로 선택"
            case .modeSelection: return "계획 방식"
            case .schedule: return "여정 기간"
            case .distance: return "목표 거리"
            case .confirm: return "확인"
            }
        }
    }

    var currentStep: Step = .routeSource
    var routeSource: RouteSource?
    var planningMode: PlanningMode?
    var startLocation: LocationResult?
    var endLocation: LocationResult?
    var waypoints: [LocationResult] = []
    var isRoundTrip: Bool = false
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 13, to: Date()) ?? Date()
    var dailyDistanceKm: Double = 30
    var routeResult: RouteResult?
    var daySegments: [DaySegment] = []
    var segmentNames: [(start: String, end: String)] = []
    var isCalculating = false
    var errorMessage: String?

    // 프리셋 경로
    var selectedPreset: PresetRoute?
    var gpxResult: GPXParseResult?
    var splittingStrategy: SplittingStrategy?

    /// 경로 계산에 사용할 전체 지점 목록 (출발지 → 경유지들 → 도착지)
    var allRoutePoints: [LocationResult] {
        var points: [LocationResult] = []
        if let start = startLocation { points.append(start) }
        points.append(contentsOf: waypoints)
        if let end = endLocation { points.append(end) }
        return points
    }

    private let locationService: LocationSearchServiceProtocol
    private let routeService: RouteCalculationServiceProtocol
    private let splittingService: RouteSplittingService
    private let gpxParser: GPXParserService

    init(
        locationService: LocationSearchServiceProtocol = NaverLocationSearchService(),
        routeService: RouteCalculationServiceProtocol = AppleRouteCalculationService(),
        splittingService: RouteSplittingService = RouteSplittingService(),
        gpxParser: GPXParserService = GPXParserService()
    ) {
        self.locationService = locationService
        self.routeService = routeService
        self.splittingService = splittingService
        self.gpxParser = gpxParser
    }

    // MARK: - 모드에 따른 활성 단계

    var activeSteps: [Step] {
        switch routeSource {
        case .manual:
            var steps: [Step] = [.routeSource, .startLocation, .endLocation, .waypoints, .modeSelection]
            switch planningMode {
            case .byDuration: steps.append(.schedule)
            case .byDistance: steps.append(.distance)
            case nil: break
            }
            steps.append(.confirm)
            return steps

        case .presetRoute:
            if splittingStrategy == .byCourse {
                // 코스별 분할: 1코스=1일, 중간 단계 없이 바로 확인
                return [.routeSource, .presetRoute, .confirm]
            }
            var steps: [Step] = [.routeSource, .presetRoute, .modeSelection]
            switch planningMode {
            case .byDuration: steps.append(.schedule)
            case .byDistance: steps.append(.distance)
            case nil: break
            }
            steps.append(.confirm)
            return steps

        case nil:
            return [.routeSource]
        }
    }

    // MARK: - 계산 프로퍼티

    var numberOfDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(days + 1, 1)
    }

    var canGoNext: Bool {
        switch currentStep {
        case .routeSource: return routeSource != nil
        case .startLocation: return startLocation != nil
        case .endLocation:
            if isRoundTrip {
                return !waypoints.isEmpty
            }
            return endLocation != nil
        case .waypoints: return true  // 선택사항
        case .presetRoute: return gpxResult != nil && splittingStrategy != nil
        case .modeSelection: return planningMode != nil
        case .schedule:
            if splittingStrategy == .byCourse { return true }
            return endDate > startDate
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
        // 프리셋 선택 단계로 돌아가면 분할 전략 초기화
        if currentStep == .presetRoute {
            splittingStrategy = nil
        }
        // 경로 입력 방식 선택으로 돌아가면 전체 리셋
        if currentStep == .routeSource {
            routeSource = nil
            waypoints = []
            selectedPreset = nil
            gpxResult = nil
            splittingStrategy = nil
            startLocation = nil
            endLocation = nil
        }
    }

    // MARK: - 프리셋 경로 불러오기

    func loadPresetRoute(_ preset: PresetRoute) {
        guard let url = preset.gpxURL else {
            errorMessage = "경로 파일을 찾을 수 없습니다."
            selectedPreset = nil
            gpxResult = nil
            return
        }
        do {
            let result = try gpxParser.parseGPX(from: url)
            selectedPreset = preset
            gpxResult = result
            errorMessage = nil
        } catch {
            selectedPreset = nil
            gpxResult = nil
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 경로 계산

    func calculateRoute() async {
        isCalculating = true
        errorMessage = nil

        do {
            let result: RouteResult

            switch routeSource {
            case .presetRoute:
                guard let gpx = gpxResult else { return }
                result = RouteResult(
                    totalDistance: gpx.totalDistance,
                    polylinePoints: gpx.polylinePoints,
                    expectedTravelTime: 0
                )
                // GPX에서 출발/도착 위치 추출
                if startLocation == nil, let first = gpx.polylinePoints.first {
                    let name = await splittingService.reverseGeocode(coordinate: first)
                    startLocation = LocationResult(
                        name: name, subtitle: "",
                        latitude: first.latitude, longitude: first.longitude
                    )
                }
                if endLocation == nil, let last = gpx.polylinePoints.last {
                    let name = await splittingService.reverseGeocode(coordinate: last)
                    endLocation = LocationResult(
                        name: name, subtitle: "",
                        latitude: last.latitude, longitude: last.longitude
                    )
                }

            case .manual, .none:
                let points = allRoutePoints
                guard points.count >= 2 else { return }

                // 다구간 경로 계산: 각 인접 구간의 폴리라인과 거리를 합산
                var allPolyline: [CLLocationCoordinate2D] = []
                var totalDistance: Double = 0
                var totalTravelTime: TimeInterval = 0

                for i in 0..<(points.count - 1) {
                    let legResult = try await routeService.calculateWalkingRoute(
                        from: points[i].coordinate,
                        to: points[i + 1].coordinate
                    )
                    // 첫 구간이 아닌 경우 중복 시작점 제거
                    if !allPolyline.isEmpty {
                        allPolyline.append(contentsOf: legResult.polylinePoints.dropFirst())
                    } else {
                        allPolyline.append(contentsOf: legResult.polylinePoints)
                    }
                    totalDistance += legResult.totalDistance
                    totalTravelTime += legResult.expectedTravelTime
                }

                result = RouteResult(
                    totalDistance: totalDistance,
                    polylinePoints: allPolyline,
                    expectedTravelTime: totalTravelTime
                )
            }

            routeResult = result

            let segments: [DaySegment]

            if splittingStrategy == .byCourse, let gpx = gpxResult, !gpx.courses.isEmpty {
                // 코스별 분할
                segments = splittingService.splitRouteByCourses(courses: gpx.courses)
                let courseCount = segments.count
                endDate = Calendar.current.date(byAdding: .day, value: courseCount - 1, to: startDate) ?? startDate
            } else {
                // 균등 분할
                let days: Int
                switch planningMode {
                case .byDuration, .none:
                    days = numberOfDays
                case .byDistance:
                    days = max(Int(ceil(result.totalDistance / (dailyDistanceKm * 1000))), 1)
                    endDate = Calendar.current.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
                }
                segments = splittingService.splitRoute(
                    polylinePoints: result.polylinePoints,
                    totalDistance: result.totalDistance,
                    numberOfDays: days
                )
            }
            daySegments = segments

            // Reverse geocode segment endpoints
            if splittingStrategy == .byCourse, let gpx = gpxResult, !gpx.courses.isEmpty {
                // 코스별: 코스 이름을 그대로 사용
                var names: [(start: String, end: String)] = []
                for (index, course) in gpx.courses.enumerated() {
                    let startName: String
                    let endName: String

                    if index == 0, let name = startLocation?.name {
                        startName = name
                    } else if index == 0 {
                        startName = await splittingService.reverseGeocode(coordinate: segments[index].startCoordinate)
                    } else {
                        startName = await splittingService.reverseGeocode(coordinate: segments[index].startCoordinate)
                        try? await Task.sleep(for: .milliseconds(300))
                    }

                    if index == gpx.courses.count - 1, let name = endLocation?.name {
                        endName = name
                    } else if index == gpx.courses.count - 1 {
                        endName = await splittingService.reverseGeocode(coordinate: segments[index].endCoordinate)
                    } else {
                        endName = await splittingService.reverseGeocode(coordinate: segments[index].endCoordinate)
                        try? await Task.sleep(for: .milliseconds(300))
                    }

                    names.append((start: startName, end: endName))
                }
                segmentNames = names
            } else {
                // 균등 분할: 기존 로직
                let points = allRoutePoints
                let firstPoint = points.first!
                let lastPoint = points.last!
                var names: [(start: String, end: String)] = []
                for segment in segments {
                    let startName: String
                    let endName: String

                    if segment.dayNumber == 1 {
                        startName = firstPoint.name
                    } else {
                        startName = await splittingService.reverseGeocode(coordinate: segment.startCoordinate)
                        try? await Task.sleep(for: .milliseconds(300))
                    }

                    if segment.dayNumber == segments.count {
                        endName = lastPoint.name
                    } else {
                        endName = await splittingService.reverseGeocode(coordinate: segment.endCoordinate)
                        try? await Task.sleep(for: .milliseconds(300))
                    }

                    names.append((start: startName, end: endName))
                }
                segmentNames = names
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isCalculating = false
    }

    // MARK: - 여정 생성

    func createJourney(in context: ModelContext) -> Journey {
        let title: String
        if isRoundTrip {
            let waypointNames = waypoints.map(\.name).joined(separator: " → ")
            title = "\(startLocation?.name ?? "") → \(waypointNames) → \(startLocation?.name ?? "")"
        } else if waypoints.isEmpty {
            title = "\(startLocation?.name ?? "") → \(endLocation?.name ?? "")"
        } else {
            let waypointNames = waypoints.map(\.name).joined(separator: " → ")
            title = "\(startLocation?.name ?? "") → \(waypointNames) → \(endLocation?.name ?? "")"
        }
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
