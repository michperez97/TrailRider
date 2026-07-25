import Foundation
import CoreLocation
import Combine

@Observable
@MainActor
final class LocationService: NSObject {
    static let shared = LocationService()

    var currentLocation: CLLocation?
    var currentSpeed: Double = 0 // mph
    var isAuthorized = false
    var signalQuality: LocationSignalQuality = .unknown
    var lastLocationUpdateAt: Date?

    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        #if os(iOS)
        locationManager.showsBackgroundLocationIndicator = true
        #endif
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking() {
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
    }

    func refreshSignalFreshness(now: Date = Date()) {
        guard let lastLocationUpdateAt else {
            signalQuality = .unknown
            return
        }

        if now.timeIntervalSince(lastLocationUpdateAt) > 12 {
            signalQuality = .stale
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        lastLocationUpdateAt = location.timestamp
        updateSignalQuality(for: location)

        // Filter out inaccurate readings
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 30 else { return }

        currentLocation = location

        // Convert m/s to mph — filter noise below 0.5 m/s (~1 mph)
        if location.speed > 0.5 {
            currentSpeed = location.speed * 2.23694
        } else {
            currentSpeed = 0
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        signalQuality = .weak
    }

    private func updateSignalQuality(for location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else {
            signalQuality = .weak
            return
        }

        if abs(location.timestamp.timeIntervalSinceNow) > 12 {
            signalQuality = .stale
        } else if location.horizontalAccuracy <= 12 {
            signalQuality = .strong
        } else if location.horizontalAccuracy < 30 {
            signalQuality = .usable
        } else {
            signalQuality = .weak
        }
    }
}
