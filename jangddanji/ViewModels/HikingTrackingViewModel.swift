import Foundation
import SwiftData
import CoreLocation

@Observable
final class HikingTrackingViewModel {

    // MARK: - State

    var elapsedTime: TimeInterval = 0
    var showRecoveryAlert = false
    var recoveredMountainName: String = ""
    var showCompleteConfirm = false

    // 서비스에서 직접 읽을 값들을 View가 관찰할 수 있도록 래핑
    var coordinates: [CLLocationCoordinate2D] { trackingService.coordinates }
    var currentLocation: CLLocationCoordinate2D? { trackingService.currentLocation }
    var totalDistanceMeters: Double { trackingService.totalDistance }
    var steps: Int { healthService.steps }
    var distanceKm: Double { healthService.distanceMeters / 1000 }
    var calories: Double { healthService.calories }
    var authorizationStatus: CLAuthorizationStatus { trackingService.authorizationStatus }

    let mountainName: String
    let mountainLatitude: Double
    let mountainLongitude: Double

    // MARK: - Services

    let trackingService: HikingTrackingService
    private let healthService: HealthKitService
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(mountainName: String, latitude: Double, longitude: Double) {
        self.mountainName = mountainName
        self.mountainLatitude = latitude
        self.mountainLongitude = longitude
        self.trackingService = HikingTrackingService()
        self.healthService = HealthKitService()
    }

    // MARK: - Lifecycle

    func onAppear() {
        // 미완료 세션 복구 확인
        if trackingService.hasSavedSession {
            recoveredMountainName = trackingService.savedSessionMountainName() ?? ""
            showRecoveryAlert = true
        } else {
            startTracking()
        }
    }

    func resumeSavedSession() {
        trackingService.resumeFromSavedSession()
        let start = trackingService.startTime ?? Date()
        elapsedTime = Date().timeIntervalSince(start)
        startHealthPolling(from: start)
        startTimer(from: start)
    }

    func discardSavedSession() {
        trackingService.discardSavedSession()
        startTracking()
    }

    private func startTracking() {
        trackingService.requestAuthorization()
        trackingService.startTracking(
            mountainName: mountainName,
            latitude: mountainLatitude,
            longitude: mountainLongitude
        )
        let now = Date()
        startHealthPolling(from: now)
        startTimer(from: now)
    }

    // MARK: - Complete

    func completeHiking(context: ModelContext) -> UUID? {
        trackingService.stopTracking()
        healthService.stopPolling()
        stopTimer()

        let endTime = Date()
        let startTime = trackingService.startTime ?? endTime

        let journey = Journey(
            title: mountainName,
            startLocationName: mountainName,
            startLatitude: mountainLatitude,
            startLongitude: mountainLongitude,
            endLocationName: mountainName,
            endLatitude: mountainLatitude,
            endLongitude: mountainLongitude,
            startDate: startTime,
            endDate: endTime,
            totalDistance: trackingService.totalDistance / 1000
        )
        journey.journeyType = "hiking"
        journey.totalSteps = steps
        journey.totalDistanceWalked = distanceKm
        journey.status = .completed

        let gpsCoordinates = trackingService.coordinates.map {
            WaypointCoordinate(name: "", latitude: $0.latitude, longitude: $0.longitude)
        }

        let dayRoute = DayRoute(
            dayNumber: 1,
            date: startTime,
            startLocationName: mountainName,
            startLatitude: mountainLatitude,
            startLongitude: mountainLongitude,
            endLocationName: mountainName,
            endLatitude: mountainLatitude,
            endLongitude: mountainLongitude,
            distance: trackingService.totalDistance / 1000,
            waypoints: gpsCoordinates
        )
        dayRoute.status = .completed
        dayRoute.journey = journey

        context.insert(journey)
        context.insert(dayRoute)
        try? context.save()

        return journey.id
    }

    // MARK: - Private

    private func startHealthPolling(from start: Date) {
        Task {
            await healthService.requestAuthorization()
            healthService.startPolling(from: start)
        }
    }

    private func startTimer(from start: Date) {
        timerTask = Task {
            while !Task.isCancelled {
                elapsedTime = Date().timeIntervalSince(start)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
