import Foundation

enum DayRouteStatus: String, Codable, CaseIterable {
    case upcoming
    case today
    case completed
    case skipped
}
