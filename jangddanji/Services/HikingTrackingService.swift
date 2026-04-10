import Foundation
import CoreLocation

// MARK: - Tracking State

enum HikingTrackingState {
    case idle
    case tracking
    case finished
}

// MARK: - Saved Session (강제 종료 복구용)

private struct SavedHikingSession: Codable {
    let mountainName: String
    let mountainLatitude: Double
    let mountainLongitude: Double
    let startTime: Date
    let coordinates: [SavedCoordinate]
    let totalDistance: Double

    struct SavedCoordinate: Codable {
        let latitude: Double
        let longitude: Double
    }
}

// MARK: - Service

@Observable
final class HikingTrackingService: NSObject {

    private(set) var state: HikingTrackingState = .idle
    private(set) var coordinates: [CLLocationCoordinate2D] = []
    private(set) var totalDistance: Double = 0  // meters
    private(set) var startTime: Date?
    private(set) var currentLocation: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var hasSavedSession: Bool { loadSavedSession() != nil }

    private let locationManager = CLLocationManager()
    private var saveTimer: Timer?
    private var mountainName: String = ""
    private var mountainLatitude: Double = 0
    private var mountainLongitude: Double = 0

    private static let savedSessionKey = "hiking_saved_session"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5  // 5m 이상 이동 시에만 업데이트
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Start / Stop

    func startTracking(mountainName: String, latitude: Double, longitude: Double) {
        self.mountainName = mountainName
        self.mountainLatitude = latitude
        self.mountainLongitude = longitude
        self.coordinates = []
        self.totalDistance = 0
        self.startTime = Date()
        self.state = .tracking

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()

        startSaveTimer()
    }

    func stopTracking() {
        state = .finished
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        stopSaveTimer()
        clearSavedSession()
    }

    // MARK: - Crash Recovery

    func resumeFromSavedSession() {
        guard let session = loadSavedSession() else { return }

        mountainName = session.mountainName
        mountainLatitude = session.mountainLatitude
        mountainLongitude = session.mountainLongitude
        startTime = session.startTime
        totalDistance = session.totalDistance
        coordinates = session.coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        state = .tracking

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()

        startSaveTimer()
    }

    func discardSavedSession() {
        clearSavedSession()
    }

    func savedSessionMountainName() -> String? {
        loadSavedSession()?.mountainName
    }

    // MARK: - Private: Timer

    private func startSaveTimer() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.persistSession()
        }
    }

    private func stopSaveTimer() {
        saveTimer?.invalidate()
        saveTimer = nil
    }

    // MARK: - Private: Persistence

    private func persistSession() {
        let session = SavedHikingSession(
            mountainName: mountainName,
            mountainLatitude: mountainLatitude,
            mountainLongitude: mountainLongitude,
            startTime: startTime ?? Date(),
            coordinates: coordinates.map {
                SavedHikingSession.SavedCoordinate(latitude: $0.latitude, longitude: $0.longitude)
            },
            totalDistance: totalDistance
        )
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Self.savedSessionKey)
        }
    }

    private func loadSavedSession() -> SavedHikingSession? {
        guard let data = UserDefaults.standard.data(forKey: Self.savedSessionKey),
              let session = try? JSONDecoder().decode(SavedHikingSession.self, from: data)
        else { return nil }
        return session
    }

    private func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: Self.savedSessionKey)
    }
}

// MARK: - CLLocationManagerDelegate

extension HikingTrackingService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard state == .tracking else { return }

        for location in locations {
            guard location.horizontalAccuracy > 0,
                  location.horizontalAccuracy < 50 else { continue }  // 정확도 50m 이내만 허용

            let coordinate = location.coordinate
            currentLocation = coordinate

            if let last = coordinates.last {
                let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
                let delta = location.distance(from: lastLocation)
                totalDistance += delta
            }

            coordinates.append(coordinate)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [HikingTracking] 위치 오류: \(error.localizedDescription)")
    }
}
