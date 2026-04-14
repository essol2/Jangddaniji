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

    /// 촬영된 클립 파일 경로 목록 (JSON: ["path1", "path2", ...])
    var diaryClipsData: Data?

    /// 합산 완료된 최종 영상 파일 경로
    var diaryVideoPath: String?

    /// 다이어리 알림 시작 시각 (기본값 8 = 오전 8시)
    var diaryNotificationStartHour: Int = 8

    /// 다이어리 알림 종료 시각 (기본값 23 = 오후 11시)
    var diaryNotificationEndHour: Int = 23

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

    /// 촬영된 클립 경로 배열 (헬퍼)
    var diaryClipPaths: [String] {
        get {
            guard let data = diaryClipsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            diaryClipsData = try? JSONEncoder().encode(newValue)
        }
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
