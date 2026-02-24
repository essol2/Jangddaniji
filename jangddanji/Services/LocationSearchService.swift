import Foundation
import MapKit

struct LocationResult: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

protocol LocationSearchServiceProtocol {
    func search(query: String) async throws -> [LocationResult]
}

final class AppleLocationSearchService: LocationSearchServiceProtocol {
    @available(iOS, deprecated: 26.0)
    func search(query: String) async throws -> [LocationResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5),
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.compactMap { item -> LocationResult? in
            let coord = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(coord) else { return nil }
            return LocationResult(
                name: item.name ?? "알 수 없는 위치",
                subtitle: item.placemark.title ?? "",
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        }
    }
}
