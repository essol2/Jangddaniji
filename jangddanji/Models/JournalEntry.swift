import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var text: String
    var photoData: Data?  // 레거시: 마이그레이션 호환용 (단일 사진)
    var createdAt: Date

    var dayRoute: DayRoute?

    @Relationship(deleteRule: .cascade, inverse: \JournalPhoto.journalEntry)
    var photos: [JournalPhoto] = []

    var sortedPhotos: [JournalPhoto] {
        photos.sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasAnyPhoto: Bool {
        photoData != nil || !photos.isEmpty
    }

    init(text: String = "", photoData: Data? = nil) {
        self.id = UUID()
        self.text = text
        self.photoData = photoData
        self.createdAt = Date()
    }
}
