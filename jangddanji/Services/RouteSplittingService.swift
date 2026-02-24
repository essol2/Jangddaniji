import Foundation
import CoreLocation

struct DaySegment {
    let dayNumber: Int
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    let distance: Double
}

protocol RouteSplittingServiceProtocol {
    func splitRoute(
        polylinePoints: [CLLocationCoordinate2D],
        totalDistance: Double,
        numberOfDays: Int
    ) -> [DaySegment]
}

final class RouteSplittingService: RouteSplittingServiceProtocol {
    func splitRoute(
        polylinePoints: [CLLocationCoordinate2D],
        totalDistance: Double,
        numberOfDays: Int
    ) -> [DaySegment] {
        guard numberOfDays > 0, polylinePoints.count >= 2 else { return [] }

        if numberOfDays == 1 {
            return [DaySegment(
                dayNumber: 1,
                startCoordinate: polylinePoints.first!,
                endCoordinate: polylinePoints.last!,
                distance: totalDistance
            )]
        }

        let dailyTarget = totalDistance / Double(numberOfDays)
        var segments: [DaySegment] = []
        var currentIndex = 0
        var accumulatedTotal: Double = 0
        var currentStartPoint = polylinePoints[0]

        for day in 1...numberOfDays {
            let isLastDay = (day == numberOfDays)

            if isLastDay {
                let remainingDistance = totalDistance - accumulatedTotal
                segments.append(DaySegment(
                    dayNumber: day,
                    startCoordinate: currentStartPoint,
                    endCoordinate: polylinePoints.last!,
                    distance: remainingDistance
                ))
                break
            }

            var segmentDistance: Double = 0
            var prevPoint = currentStartPoint

            while currentIndex < polylinePoints.count - 1 {
                let nextPoint = polylinePoints[currentIndex + 1]
                let edgeDistance = CLLocation(
                    latitude: prevPoint.latitude,
                    longitude: prevPoint.longitude
                ).distance(from: CLLocation(
                    latitude: nextPoint.latitude,
                    longitude: nextPoint.longitude
                ))

                if segmentDistance + edgeDistance >= dailyTarget {
                    let remaining = dailyTarget - segmentDistance
                    let fraction = edgeDistance > 0 ? remaining / edgeDistance : 0
                    let splitLat = prevPoint.latitude + (nextPoint.latitude - prevPoint.latitude) * fraction
                    let splitLon = prevPoint.longitude + (nextPoint.longitude - prevPoint.longitude) * fraction
                    let splitPoint = CLLocationCoordinate2D(latitude: splitLat, longitude: splitLon)

                    segments.append(DaySegment(
                        dayNumber: day,
                        startCoordinate: currentStartPoint,
                        endCoordinate: splitPoint,
                        distance: dailyTarget
                    ))
                    accumulatedTotal += dailyTarget
                    currentStartPoint = splitPoint
                    break
                } else {
                    segmentDistance += edgeDistance
                    currentIndex += 1
                    prevPoint = nextPoint
                }
            }

            if segments.count < day {
                segments.append(DaySegment(
                    dayNumber: day,
                    startCoordinate: currentStartPoint,
                    endCoordinate: polylinePoints[min(currentIndex, polylinePoints.count - 1)],
                    distance: segmentDistance
                ))
                accumulatedTotal += segmentDistance
                currentStartPoint = polylinePoints[min(currentIndex, polylinePoints.count - 1)]
            }
        }

        return segments
    }

    @available(iOS, deprecated: 26.0)
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return placemark.locality
                    ?? placemark.subLocality
                    ?? placemark.thoroughfare
                    ?? placemark.name
                    ?? "알 수 없는 위치"
            }
        } catch {}

        return "알 수 없는 위치"
    }
}
