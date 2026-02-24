import Foundation
import SwiftData

@Model
final class JournalPhoto {
    var id: UUID
    var photoData: Data
    var sortOrder: Int
    var createdAt: Date

    var journalEntry: JournalEntry?

    init(photoData: Data, sortOrder: Int = 0) {
        self.id = UUID()
        self.photoData = photoData
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
