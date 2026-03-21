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
    }
}
