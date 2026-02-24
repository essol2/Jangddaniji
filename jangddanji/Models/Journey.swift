import Foundation
import SwiftData

@Model
final class Journey {
    var id: UUID
    var title: String

    var startLocationName: String
    var startLatitude: Double
    var startLongitude: Double

    var endLocationName: String
    var endLatitude: Double
    var endLongitude: Double

    var startDate: Date
    var endDate: Date
    var totalDistance: Double

    var statusRawValue: String
    var status: JourneyStatus {
        get { JourneyStatus(rawValue: statusRawValue) ?? .planning }
        set { statusRawValue = newValue.rawValue }
    }

    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DayRoute.journey)
    var dayRoutes: [DayRoute] = []

    var sortedDayRoutes: [DayRoute] {
        dayRoutes.sorted { $0.dayNumber < $1.dayNumber }
    }

    var numberOfDays: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1
    }

    init(
        title: String,
        startLocationName: String,
        startLatitude: Double,
        startLongitude: Double,
        endLocationName: String,
        endLatitude: Double,
        endLongitude: Double,
        startDate: Date,
        endDate: Date,
        totalDistance: Double
    ) {
        self.id = UUID()
        self.title = title
        self.startLocationName = startLocationName
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLocationName = endLocationName
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.startDate = startDate
        self.endDate = endDate
        self.totalDistance = totalDistance
        self.statusRawValue = JourneyStatus.planning.rawValue
        self.createdAt = Date()
    }
}
