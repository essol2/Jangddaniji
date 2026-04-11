import Foundation
import SwiftData

@Model
final class DayRoute {
    var id: UUID
    var dayNumber: Int
    var date: Date

    var startLocationName: String
    var startLatitude: Double
    var startLongitude: Double

    var endLocationName: String
    var endLatitude: Double
    var endLongitude: Double

    var distance: Double

    /// 해당 일자 실제 걸음수
    var actualSteps: Int = 0
    /// 해당 일자 실제 이동거리 (km)
    var actualDistanceWalked: Double = 0

    /// 경유지 좌표 목록 (JSON: [[lat, lon], ...])
    var waypointsData: Data?

    var statusRawValue: String
    var status: DayRouteStatus {
        get { DayRouteStatus(rawValue: statusRawValue) ?? .upcoming }
        set { statusRawValue = newValue.rawValue }
    }

    var journey: Journey?

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.dayRoute)
    var journalEntry: JournalEntry?

    init(
        dayNumber: Int,
        date: Date,
        startLocationName: String,
        startLatitude: Double,
        startLongitude: Double,
        endLocationName: String,
        endLatitude: Double,
        endLongitude: Double,
        distance: Double,
        waypoints: [WaypointCoordinate] = []
    ) {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.date = date
        self.startLocationName = startLocationName
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLocationName = endLocationName
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.distance = distance
        self.statusRawValue = DayRouteStatus.upcoming.rawValue
        self.waypointsData = try? JSONEncoder().encode(waypoints)
    }

    /// 경유지 좌표 배열 (디코딩)
    var waypointCoordinates: [WaypointCoordinate] {
        guard let data = waypointsData else { return [] }
        return (try? JSONDecoder().decode([WaypointCoordinate].self, from: data)) ?? []
    }
}

/// 경유지 좌표를 JSON으로 저장하기 위한 경량 모델
struct WaypointCoordinate: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
}
