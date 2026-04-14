import SwiftUI
import SwiftData
import UserNotifications
// [AD-DISABLED] import GoogleMobileAds
// [AD-DISABLED] import AppTrackingTransparency

@main
struct jangddanjiApp: App {
//    [AD-DISABLED] init() {
//        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["829618ddb23b6e54fc796f1fba9b701f"]
//    }

    private let sharedModelContainer: ModelContainer?
    @State private var databaseError: String?
    @State private var router = AppRouter()
    private let notificationDelegate = DiaryNotificationDelegate()

    init() {
        let schema = Schema([
            Journey.self,
            DayRoute.self,
            JournalEntry.self,
            JournalPhoto.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            self.sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            self.sharedModelContainer = nil
            self._databaseError = State(initialValue: "데이터베이스를 열 수 없습니다: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                NavigationStack(path: $router.path) {
                    EntryView()
                        .navigationDestination(for: AppDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .environment(router)
                .modelContainer(container)
                .task {
                    migratePhotoDataIfNeeded()
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    notificationDelegate.router = router
                }
                // [AD-DISABLED] .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                //     requestTrackingPermission()
                // }
            } else {
                DatabaseErrorView(errorMessage: databaseError ?? "알 수 없는 오류")
            }
        }
    }

    // [AD-DISABLED] private func requestTrackingPermission() {
    //     ATTrackingManager.requestTrackingAuthorization { status in
    //         // ATT 응답 후 AdMob 초기화 (허용/거부 상관없이)
    //         GADMobileAds.sharedInstance().start(completionHandler: nil)
    //         InterstitialAdManager.shared.loadAd()
    //     }
    // }

    private func migratePhotoDataIfNeeded() {
        guard let container = sharedModelContainer else { return }
        let context = container.mainContext
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
        case .journeyComplete(let id):
            JourneyCompleteView(journeyID: id)
        case .backup:
            BackupView()
        case .diaryRecording(let dayRouteID, let hour):
            DiaryRecordingView(dayRouteID: dayRouteID, hour: hour)
        case .diaryPlayer(let videoPath):
            DiaryVideoPlayerView(videoPath: videoPath)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

final class DiaryNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var router: AppRouter?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["dayRouteID"] as? String,
           let dayRouteID = UUID(uuidString: idString) {
            let hour = Calendar.current.component(.hour, from: Date())
            DispatchQueue.main.async {
                self.router?.navigateTo(.diaryRecording(dayRouteID: dayRouteID, hour: hour))
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
