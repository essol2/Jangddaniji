import Foundation
import ActivityKit

struct WalkingActivityAttributes: ActivityAttributes {
    // 고정 데이터: 활동 시작 시 설정, 변경 불가
    var journeyTitle: String
    var dayNumber: Int
    var startLocationName: String
    var endLocationName: String
    var totalDistanceMeters: Double

    // 동적 데이터: 실시간 업데이트
    struct ContentState: Codable, Hashable {
        var todaySteps: Int
        var todayDistanceKm: Double
        var progress: Double       // 0.0 ~ 1.0
        var isCompleted: Bool
    }
}
