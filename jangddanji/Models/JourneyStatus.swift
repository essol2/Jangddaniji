import Foundation

enum JourneyStatus: String, Codable, CaseIterable {
    case planning
    case active
    case completed
    case abandoned
}
