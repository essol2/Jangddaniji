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
        distance: Double
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
    }
}
