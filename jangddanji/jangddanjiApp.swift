import SwiftUI
import SwiftData

@main
struct jangddanjiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Journey.self,
            DayRoute.self,
            JournalEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
        }
        .modelContainer(sharedModelContainer)
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
