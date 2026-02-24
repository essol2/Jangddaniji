import Foundation

enum DistanceFormatter {
    static func formatted(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.0fkm", meters / 1000)
        } else {
            return String(format: "%.0fm", meters)
        }
    }

    static func formattedDetailed(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        } else {
            return String(format: "%.0fm", meters)
        }
    }

    static func kilometers(_ meters: Double) -> Int {
        Int(meters / 1000)
    }
}
