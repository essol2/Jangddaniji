import SwiftUI
import SwiftData

@main
struct jangddanjiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Journey.self,
            DayRoute.self,
            JournalEntry.self,
            JournalPhoto.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // 개발 중 스키마 변경 시 기존 스토어 삭제 후 재생성
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            // WAL, SHM 파일도 삭제
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                EntryView()
                    .navigationDestination(for: AppDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .environment(router)
            .task {
                migratePhotoDataIfNeeded()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func migratePhotoDataIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<JournalEntry>()
        guard let entries = try? context.fetch(descriptor) else { return }

        var didMigrate = false
        for entry in entries {
            if let legacyData = entry.photoData {
                let photo = JournalPhoto(photoData: legacyData, sortOrder: 0)
                photo.journalEntry = entry
                entry.photos.append(photo)
                context.insert(photo)
                entry.photoData = nil
                didMigrate = true
            }
        }
        if didMigrate {
            try? context.save()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .planning:
            PlanningContainerView()
        case .dashboard:
            DashboardView()
        case .dayDetail(let id):
            DayDetailView(dayRouteID: id)
        case .routeModify(let id):
            RouteModifyView(dayRouteID: id)
        case .archiveList:
            JourneyArchiveListView()
        case .archiveDetail(let id):
            JourneyArchiveDetailView(journeyID: id)
        }
    }
}
