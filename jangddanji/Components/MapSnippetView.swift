import SwiftUI
import MapKit
import CoreLocation

struct MapSnippetView: View {
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    var waypoints: [WaypointCoordinate] = []

    private var region: MKCoordinateRegion {
        // 출발/도착/경유지 모든 좌표를 포함하는 영역 계산
        var allLats = [startCoordinate.latitude, endCoordinate.latitude]
        var allLons = [startCoordinate.longitude, endCoordinate.longitude]
        for wp in waypoints {
            allLats.append(wp.latitude)
            allLons.append(wp.longitude)
        }
        let minLat = allLats.min()!
        let maxLat = allLats.max()!
        let minLon = allLons.min()!
        let maxLon = allLons.max()!
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = max((maxLat - minLat) * 1.8, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.8, 0.01)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            Marker("출발", coordinate: startCoordinate)
                .tint(AppColors.primaryBlueDark)

            ForEach(Array(waypoints.enumerated()), id: \.offset) { index, wp in
                Marker(
                    "경유 \(index + 1)",
                    coordinate: CLLocationCoordinate2D(latitude: wp.latitude, longitude: wp.longitude)
                )
                .tint(.orange)
            }

            Marker("도착", coordinate: endCoordinate)
                .tint(.red)
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
