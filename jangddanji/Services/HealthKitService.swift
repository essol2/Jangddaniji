import Foundation
import HealthKit

@Observable
final class HealthKitService {

    private(set) var steps: Int = 0
    private(set) var distanceMeters: Double = 0
    private(set) var calories: Double = 0
    private(set) var isAuthorized = false

    private let store = HKHealthStore()
    private var pollTask: Task<Void, Never>?
    private var sessionStart: Date?

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    ]

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            print("❌ [HealthKit] 권한 요청 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Polling

    func startPolling(from start: Date) {
        sessionStart = start
        steps = 0
        distanceMeters = 0
        calories = 0

        pollTask = Task {
            while !Task.isCancelled {
                await fetchAll(from: start)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Private

    private func fetchAll(from start: Date) async {
        async let s = fetchQuantity(.stepCount, unit: .count(), from: start)
        async let d = fetchQuantity(.distanceWalkingRunning, unit: .meter(), from: start)
        async let c = fetchQuantity(.activeEnergyBurned, unit: .kilocalorie(), from: start)

        let (newSteps, newDistance, newCalories) = await (s, d, c)
        steps = Int(newSteps)
        distanceMeters = newDistance
        calories = newCalories
    }

    private func fetchQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date
    ) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
