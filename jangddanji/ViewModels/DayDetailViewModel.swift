import Foundation
import SwiftData
import CoreLocation
import UIKit

@Observable
final class DayDetailViewModel {
    private(set) var dayRoute: DayRoute
    private let mapService = ExternalMapService()
    private var saveTask: Task<Void, Never>?

    init(dayRoute: DayRoute) {
        self.dayRoute = dayRoute
    }

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: dayRoute.startLatitude, longitude: dayRoute.startLongitude)
    }

    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: dayRoute.endLatitude, longitude: dayRoute.endLongitude)
    }

    var initialText: String {
        dayRoute.journalEntry?.text ?? ""
    }

    var initialPhotoData: Data? {
        dayRoute.journalEntry?.photoData
    }

    var availableMapApps: [MapApp] {
        mapService.availableApps()
    }

    func scheduleSave(text: String, photoData: Data?, context: ModelContext) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self.saveJournal(text: text, photoData: photoData, context: context)
        }
    }

    func saveJournal(text: String, photoData: Data?, context: ModelContext) {
        if let entry = dayRoute.journalEntry {
            entry.text = text
            entry.photoData = photoData
        } else if !text.isEmpty || photoData != nil {
            let entry = JournalEntry(text: text, photoData: photoData)
            entry.dayRoute = dayRoute
            dayRoute.journalEntry = entry
            context.insert(entry)
        }
        try? context.save()
    }

    @available(iOS, deprecated: 26.0)
    func openDirections(with app: MapApp) {
        mapService.openDirections(
            app: app,
            from: startCoordinate,
            fromName: dayRoute.startLocationName,
            to: endCoordinate,
            toName: dayRoute.endLocationName
        )
    }

    static func compressImage(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let size = image.size
        let scale = maxDimension / max(size.width, size.height)
        let targetSize = scale < 1
            ? CGSize(width: size.width * scale, height: size.height * scale)
            : size
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
