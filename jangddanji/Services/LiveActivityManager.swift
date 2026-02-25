import Foundation
import ActivityKit
import HealthKit

@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<WalkingActivityAttributes>?
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var totalDistanceMeters: Double = 0

    private init() {}

    // MARK: - Public API

    var isActivityActive: Bool {
        currentActivity != nil
    }

    func startActivity(
        journeyTitle: String,
        dayNumber: Int,
        startLocationName: String,
        endLocationName: String,
        totalDistanceMeters: Double,
        todaySteps: Int,
        todayDistanceKm: Double
    ) {
        let authInfo = ActivityAuthorizationInfo()
        print("[LiveActivity] areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] ⚠️ Live Activity 권한이 비활성화되어 있음. 설정 > 장딴지 > 실시간 현황 활성화 필요")
            return
        }

        // 기존 활동이 있으면 먼저 종료
        if currentActivity != nil {
            endActivity(isCompleted: false)
        }

        self.totalDistanceMeters = totalDistanceMeters

        let attributes = WalkingActivityAttributes(
            journeyTitle: journeyTitle,
            dayNumber: dayNumber,
            startLocationName: startLocationName,
            endLocationName: endLocationName,
            totalDistanceMeters: totalDistanceMeters
        )

        let progress = calculateProgress(
            todayDistanceKm: todayDistanceKm,
            totalDistanceMeters: totalDistanceMeters
        )

        let initialState = WalkingActivityAttributes.ContentState(
            todaySteps: todaySteps,
            todayDistanceKm: todayDistanceKm,
            progress: progress,
            isCompleted: false
        )

        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(15 * 60)
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("[LiveActivity] ✅ 활동 생성 성공! id: \(currentActivity?.id ?? "nil")")
            startBackgroundHealthKitObserving()
        } catch {
            print("[LiveActivity] ❌ 시작 실패: \(error.localizedDescription)")
        }
    }

    func updateActivity(
        todaySteps: Int,
        todayDistanceKm: Double,
        totalDistanceMeters: Double,
        isCompleted: Bool
    ) {
        guard let activity = currentActivity else { return }

        self.totalDistanceMeters = totalDistanceMeters

        let progress = calculateProgress(
            todayDistanceKm: todayDistanceKm,
            totalDistanceMeters: totalDistanceMeters
        )

        let state = WalkingActivityAttributes.ContentState(
            todaySteps: todaySteps,
            todayDistanceKm: todayDistanceKm,
            progress: progress,
            isCompleted: isCompleted
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60)
        )

        Task {
            await activity.update(content)
        }
    }

    func endActivity(isCompleted: Bool) {
        guard let activity = currentActivity else { return }

        stopBackgroundHealthKitObserving()

        let finalState = WalkingActivityAttributes.ContentState(
            todaySteps: 0,
            todayDistanceKm: 0,
            progress: isCompleted ? 1.0 : 0,
            isCompleted: isCompleted
        )

        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        Task {
            await activity.end(content, dismissalPolicy: isCompleted ? .default : .immediate)
            await MainActor.run {
                self.currentActivity = nil
            }
        }
    }

    /// 앱 재시작 시 기존 활동 정리
    func cleanupStaleActivities() {
        Task {
            for activity in Activity<WalkingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - HealthKit Background Delivery

    private func startBackgroundHealthKitObserving() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let stepsType = HKQuantityType(.stepCount)
        let distanceType = HKQuantityType(.distanceWalkingRunning)

        // Background delivery 등록
        healthStore.enableBackgroundDelivery(for: stepsType, frequency: .hourly) { success, error in
            if let error {
                print("[LiveActivity] Steps background delivery 실패: \(error.localizedDescription)")
            }
        }

        healthStore.enableBackgroundDelivery(for: distanceType, frequency: .hourly) { success, error in
            if let error {
                print("[LiveActivity] Distance background delivery 실패: \(error.localizedDescription)")
            }
        }

        // Observer query 설정 — 걸음수 변경 시 트리거
        let query = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] _, _, _ in
            self?.fetchAndUpdateLiveActivity()
        }
        healthStore.execute(query)
        observerQuery = query
    }

    private func stopBackgroundHealthKitObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }

        let stepsType = HKQuantityType(.stepCount)
        let distanceType = HKQuantityType(.distanceWalkingRunning)

        healthStore.disableBackgroundDelivery(for: stepsType) { _, _ in }
        healthStore.disableBackgroundDelivery(for: distanceType) { _, _ in }
    }

    private func fetchAndUpdateLiveActivity() {
        guard currentActivity != nil else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        var fetchedSteps: Int = 0
        var fetchedDistanceKm: Double = 0
        let group = DispatchGroup()

        // Fetch steps
        group.enter()
        let stepsQuery = HKStatisticsQuery(
            quantityType: HKQuantityType(.stepCount),
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            fetchedSteps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            group.leave()
        }
        healthStore.execute(stepsQuery)

        // Fetch distance
        group.enter()
        let distanceQuery = HKStatisticsQuery(
            quantityType: HKQuantityType(.distanceWalkingRunning),
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            fetchedDistanceKm = meters / 1000.0
            group.leave()
        }
        healthStore.execute(distanceQuery)

        group.notify(queue: .main) { [weak self] in
            guard let self, let _ = self.currentActivity else { return }
            self.updateActivity(
                todaySteps: fetchedSteps,
                todayDistanceKm: fetchedDistanceKm,
                totalDistanceMeters: self.totalDistanceMeters,
                isCompleted: false
            )
        }
    }

    // MARK: - Helpers

    private func calculateProgress(todayDistanceKm: Double, totalDistanceMeters: Double) -> Double {
        guard totalDistanceMeters > 0 else { return 0 }
        return min(todayDistanceKm / (totalDistanceMeters / 1000.0), 1.0)
    }
}
