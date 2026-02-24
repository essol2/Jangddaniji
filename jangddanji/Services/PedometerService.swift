import Foundation
import HealthKit

@Observable
final class PedometerService {
    var todaySteps: Int = 0
    var todayDistanceKm: Double = 0
    var totalSteps: Int = 0
    var totalDistanceKm: Double = 0
    var isAuthorized = false

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var periodStartDate: Date?

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning)
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.fetchTodayData()
                    if let startDate = self?.periodStartDate {
                        self?.fetchPeriodData(from: startDate)
                    }
                    self?.startObserving()
                }
            }
        }
    }

    func setPeriodStart(_ date: Date) {
        periodStartDate = Calendar.current.startOfDay(for: date)
        if isAuthorized, let startDate = periodStartDate {
            fetchPeriodData(from: startDate)
        }
    }

    func fetchTodayData() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        // Fetch steps
        let stepsType = HKQuantityType(.stepCount)
        let stepsQuery = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async {
                self?.todaySteps = Int(steps)
            }
        }
        healthStore.execute(stepsQuery)

        // Fetch distance
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let distanceQuery = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            DispatchQueue.main.async {
                self?.todayDistanceKm = meters / 1000.0
            }
        }
        healthStore.execute(distanceQuery)
    }

    func fetchPeriodData(from startDate: Date) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        // Fetch total steps for period
        let stepsType = HKQuantityType(.stepCount)
        let stepsQuery = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async {
                self?.totalSteps = Int(steps)
            }
        }
        healthStore.execute(stepsQuery)

        // Fetch total distance for period
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let distanceQuery = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            DispatchQueue.main.async {
                self?.totalDistanceKm = meters / 1000.0
            }
        }
        healthStore.execute(distanceQuery)
    }

    private func startObserving() {
        let stepsType = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] _, _, _ in
            self?.fetchTodayData()
            if let startDate = self?.periodStartDate {
                self?.fetchPeriodData(from: startDate)
            }
        }
        healthStore.execute(query)
        observerQuery = query
    }
}
