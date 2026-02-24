import SwiftUI
import MapKit
import CoreLocation

struct MapSnippetView: View {
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D

    private var region: MKCoordinateRegion {
        let centerLat = (startCoordinate.latitude + endCoordinate.latitude) / 2
        let centerLon = (startCoordinate.longitude + endCoordinate.longitude) / 2
        let latDelta = max(abs(startCoordinate.latitude - endCoordinate.latitude) * 1.8, 0.01)
        let lonDelta = max(abs(startCoordinate.longitude - endCoordinate.longitude) * 1.8, 0.01)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            Marker("출발", coordinate: startCoordinate)
                .tint(AppColors.primaryBlueDark)
            Marker("도착", coordinate: endCoordinate)
                .tint(.red)
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
