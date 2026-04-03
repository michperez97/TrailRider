import Foundation
import CoreLocation
import MapKit
import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class RideViewModel {

    enum RideState: Equatable {
        case idle
        case riding
        case paused
        case summary
    }

    enum MapStyle: String, CaseIterable {
        case standard
        case satellite
    }

    // MARK: - State

    var rideState: RideState = .idle
    var savedRide: Ride?
    var isSaving = false
    var saveError: String?
    var elapsedSeconds: Int = 0
    var distanceMiles: Double = 0
    var currentSpeedMph: Double = 0
    var maxSpeedMph: Double = 0
    var avgSpeedMph: Double = 0
    var elevationGainFeet: Double = 0
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var mapStyleSelection: MapStyle = .standard

    // MARK: - Heart Rate (from Watch)
    var heartRate: Double = 0
    var hrZone: Int = 0
    var hrZoneColor: Color = .gray
    var hrZoneName: String = "--"
    var activeCalories: Double = 0
    var isWatchConnected: Bool = false

    // MARK: - Private

    private let locationService = LocationService.shared
    private let rideService = RideService.shared
    private let watchService = WatchConnectivityService.shared
    private var timer: Timer?
    private var rideStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var lastLocation: CLLocation?
    private var lastElevation: Double?

    // MARK: - Formatted Properties

    var formattedDuration: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        String(format: "%.2f", distanceMiles)
    }

    var formattedSpeed: String {
        String(format: "%.1f", currentSpeedMph)
    }

    var formattedMaxSpeed: String {
        String(format: "%.1f", maxSpeedMph)
    }

    var formattedAvgSpeed: String {
        String(format: "%.1f", avgSpeedMph)
    }

    var formattedElevation: String {
        String(format: "%.0f", elevationGainFeet)
    }

    // MARK: - Controls

    func startRide() {
        locationService.requestAlwaysPermission()
        locationService.startTracking()

        rideState = .riding
        rideStartTime = Date()
        savedRide = nil
        elapsedSeconds = 0
        distanceMiles = 0
        currentSpeedMph = 0
        maxSpeedMph = 0
        avgSpeedMph = 0
        elevationGainFeet = 0
        routeCoordinates = []
        lastLocation = nil
        lastElevation = nil
        pausedDuration = 0
        pauseStartTime = nil

        startTimer()
    }

    func pauseRide() {
        rideState = .paused
        pauseStartTime = Date()
        stopTimer()
        locationService.stopTracking()
    }

    func resumeRide() {
        rideState = .riding
        locationService.startTracking()
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        lastLocation = nil
        startTimer()
    }

    func stopRide(userId: String?) {
        stopTimer()
        locationService.stopTracking()
        watchService.sendMessageToWatch(["rideEnded": true])

        // Build and save ride (skip junk rides under 30s or 0 distance)
        if let userId, let startTime = rideStartTime,
           elapsedSeconds > 30, distanceMiles > 0.01 {
            let computedAvg = elapsedSeconds > 0
                ? distanceMiles / (Double(elapsedSeconds) / 3600.0)
                : 0.0
            let ride = Ride(
                userId: userId,
                startTime: startTime,
                endTime: Date(),
                durationSeconds: elapsedSeconds,
                distanceMiles: distanceMiles,
                maxSpeedMph: maxSpeedMph,
                avgSpeedMph: computedAvg,
                elevationGainFeet: elevationGainFeet,
                routePolyline: routeCoordinates.map {
                    GeoPoint(latitude: $0.latitude, longitude: $0.longitude)
                },
                photoURLs: []
            )
            savedRide = ride

            isSaving = true
            saveError = nil
            Task {
                do {
                    _ = try await rideService.saveRide(ride)
                } catch {
                    saveError = "Failed to save ride: \(error.localizedDescription)"
                }
                isSaving = false
            }
        }

        rideState = .summary
    }

    func discardRide() {
        stopTimer()
        locationService.stopTracking()
        watchService.sendMessageToWatch(["rideEnded": true])
        resetRide()
    }

    func saveStandaloneWatchRide(_ data: [String: Any], userId: String) async {
        guard let startTs = data["startTime"] as? TimeInterval,
              let endTs = data["endTime"] as? TimeInterval,
              let duration = data["durationSeconds"] as? Int,
              let distMeters = data["distanceMeters"] as? Double,
              let coords = data["routeCoordinates"] as? [[String: Double]] else { return }

        let miles = distMeters / 1609.344
        let avg = duration > 0 ? miles / (Double(duration) / 3600.0) : 0

        let ride = Ride(
            userId: userId,
            startTime: Date(timeIntervalSince1970: startTs),
            endTime: Date(timeIntervalSince1970: endTs),
            durationSeconds: duration,
            distanceMiles: miles,
            maxSpeedMph: 0,
            avgSpeedMph: avg,
            elevationGainFeet: 0,
            routePolyline: coords.compactMap { c in
                guard let lat = c["lat"], let lon = c["lon"] else { return nil }
                return GeoPoint(latitude: lat, longitude: lon)
            },
            photoURLs: []
        )

        do {
            _ = try await rideService.saveRide(ride)
        } catch {
            saveError = "Failed to save Watch ride: \(error.localizedDescription)"
        }
    }

    func finishSummary() {
        resetRide()
    }

    // MARK: - Timer

    private func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if let start = rideStartTime {
            elapsedSeconds = Int(Date().timeIntervalSince(start) - pausedDuration)
        }
        updateStats()
        updateHeartRate()
    }

    // MARK: - Stats Calculation

    private func updateStats() {
        guard let location = locationService.currentLocation else { return }

        currentSpeedMph = locationService.currentSpeed

        // Track max speed
        if currentSpeedMph > maxSpeedMph {
            maxSpeedMph = currentSpeedMph
        }

        if elapsedSeconds > 0 {
            avgSpeedMph = distanceMiles / (Double(elapsedSeconds) / 3600.0)
        }

        // Calculate distance and only append route point on real movement
        if let last = lastLocation {
            let deltaMeters = location.distance(from: last)
            if deltaMeters > 2 && deltaMeters < 100 {
                distanceMiles += deltaMeters / 1609.344
                routeCoordinates.append(location.coordinate)
            }
        } else {
            // First point
            routeCoordinates.append(location.coordinate)
        }

        // Calculate elevation gain
        if location.verticalAccuracy >= 0 && location.verticalAccuracy < 20 {
            let currentElevation = location.altitude * 3.28084 // meters to feet
            if let lastElev = lastElevation {
                let delta = currentElevation - lastElev
                if delta > 1 {
                    elevationGainFeet += delta
                }
            }
            lastElevation = currentElevation
        }

        lastLocation = location
    }

    private func updateHeartRate() {
        heartRate = watchService.heartRate
        hrZone = watchService.hrZone
        hrZoneColor = watchService.hrZoneColor
        hrZoneName = watchService.hrZoneName
        activeCalories = watchService.activeCalories
        isWatchConnected = watchService.isWatchReachable
    }

    private func parseDate(from value: Any?) -> Date? {
        switch value {
        case let date as Date:
            return date
        case let number as NSNumber:
            return Date(timeIntervalSince1970: number.doubleValue)
        case let timeInterval as TimeInterval:
            return Date(timeIntervalSince1970: timeInterval)
        default:
            return nil
        }
    }

    private func doubleValue(from value: Any?) -> Double {
        switch value {
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        case let int as Int:
            return Double(int)
        default:
            return 0
        }
    }

    private func intValue(from value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let double as Double:
            return Int(double)
        default:
            return 0
        }
    }

    private func parseRouteCoordinates(from value: Any?) -> [CLLocationCoordinate2D] {
        if let coordinates = value as? [[String: Any]] {
            return coordinates.compactMap { coordinate in
                guard
                    let latitude = dictionaryDoubleValue(from: coordinate["latitude"]),
                    let longitude = dictionaryDoubleValue(from: coordinate["longitude"])
                else {
                    return nil
                }

                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }

        guard let coordinates = value as? [[AnyHashable: Any]] else { return [] }
        return coordinates.compactMap { coordinate in
            guard
                let latitude = dictionaryDoubleValue(from: coordinate["latitude"]),
                let longitude = dictionaryDoubleValue(from: coordinate["longitude"])
            else {
                return nil
            }

            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private func dictionaryDoubleValue(from value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        case let int as Int:
            return Double(int)
        default:
            return nil
        }
    }

    private func resetRide() {
        rideState = .idle
        elapsedSeconds = 0
        distanceMiles = 0
        currentSpeedMph = 0
        maxSpeedMph = 0
        avgSpeedMph = 0
        elevationGainFeet = 0
        routeCoordinates = []
        lastLocation = nil
        lastElevation = nil
        pausedDuration = 0
        pauseStartTime = nil
    }
}
