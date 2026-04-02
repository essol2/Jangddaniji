import Foundation
import MapKit

struct RouteResult {
    let totalDistance: Double
    let polylinePoints: [CLLocationCoordinate2D]
    let expectedTravelTime: TimeInterval
}

enum RouteCalculationError: LocalizedError {
    case noRouteFound
    case calculationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "경로를 찾을 수 없습니다."
        case .calculationFailed(let message):
            return "경로 계산 실패: \(message)"
        }
    }
}

protocol RouteCalculationServiceProtocol {
    func calculateWalkingRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> RouteResult

    func calculateWalkingRoute(
        through coordinates: [CLLocationCoordinate2D]
    ) async throws -> RouteResult
}

final class AppleRouteCalculationService: RouteCalculationServiceProtocol {
    @available(iOS, deprecated: 26.0)
    func calculateWalkingRoute(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RouteCalculationError.noRouteFound
        }

        let pointCount = route.polyline.pointCount
        let points = route.polyline.points()
        var coordinates: [CLLocationCoordinate2D] = []
        for i in 0..<pointCount {
            coordinates.append(points[i].coordinate)
        }

        return RouteResult(
            totalDistance: route.distance,
            polylinePoints: coordinates,
            expectedTravelTime: route.expectedTravelTime
        )
    }

    @available(iOS, deprecated: 26.0)
    func calculateWalkingRoute(
        through coordinates: [CLLocationCoordinate2D]
    ) async throws -> RouteResult {
        guard coordinates.count >= 2 else {
            throw RouteCalculationError.noRouteFound
        }

        if coordinates.count == 2 {
            return try await calculateWalkingRoute(from: coordinates[0], to: coordinates[1])
        }

        var allPolylinePoints: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0
        var totalTime: TimeInterval = 0

        for i in 0..<(coordinates.count - 1) {
            let segmentResult = try await calculateWalkingRoute(
                from: coordinates[i],
                to: coordinates[i + 1]
            )

            if i > 0 && !allPolylinePoints.isEmpty {
                allPolylinePoints.append(contentsOf: segmentResult.polylinePoints.dropFirst())
            } else {
                allPolylinePoints.append(contentsOf: segmentResult.polylinePoints)
            }

            totalDistance += segmentResult.totalDistance
            totalTime += segmentResult.expectedTravelTime
        }

        return RouteResult(
            totalDistance: totalDistance,
            polylinePoints: allPolylinePoints,
            expectedTravelTime: totalTime
        )
    }
}
