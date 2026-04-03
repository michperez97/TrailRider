import Foundation
import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

@Observable
@MainActor
final class RideReplayViewModel {

    // MARK: - Enums

    enum ReplayState {
        case idle
        case playing
        case paused
    }

    enum ViewMode: String {
        case topDown = "2D"
        case flyover = "3D"
    }

    enum PlaybackSpeed: Double, CaseIterable {
        case x2 = 2
        case x5 = 5
        case x10 = 10
        case x20 = 20

        var label: String {
            switch self {
            case .x2: return "2x"
            case .x5: return "5x"
            case .x10: return "10x"
            case .x20: return "20x"
            }
        }
    }

    // MARK: - State

    var replayState: ReplayState = .idle
    var viewMode: ViewMode = .topDown
    var playbackSpeed: PlaybackSpeed = .x5
    var currentIndex: Int = 0
    var cameraPosition: MapCameraPosition = .automatic

    // MARK: - Current Stats

    var currentSpeed: Double = 0
    var currentElevation: Double = 0
    var currentHeartRate: Double? = nil
    var currentDistance: Double = 0
    var currentTime: Double = 0

    // MARK: - Data

    let ride: Ride
    let routePoints: [Ride.RoutePoint]
    let totalDuration: Double

    private var timer: Timer?

    // MARK: - Computed

    var progress: Double {
        guard routePoints.count > 1 else { return 0 }
        return Double(currentIndex) / Double(routePoints.count - 1)
    }

    var currentCoordinate: CLLocationCoordinate2D? {
        guard currentIndex < routePoints.count else { return nil }
        let pt = routePoints[currentIndex]
        return CLLocationCoordinate2D(latitude: pt.latitude, longitude: pt.longitude)
    }

    var traveledCoordinates: [CLLocationCoordinate2D] {
        guard currentIndex < routePoints.count else { return [] }
        return Array(routePoints.prefix(currentIndex + 1)).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var allCoordinates: [CLLocationCoordinate2D] {
        routePoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedTotalTime: String {
        formatTime(totalDuration)
    }

    // MARK: - Init

    init(ride: Ride) {
        self.ride = ride

        if let points = ride.routePoints, !points.isEmpty {
            self.routePoints = points
        } else {
            // Interpolate from routePolyline for legacy rides
            let geoPoints = ride.routePolyline
            let count = geoPoints.count
            let duration = Double(ride.durationSeconds)
            self.routePoints = geoPoints.enumerated().map { index, gp in
                let t = count > 1 ? (duration * Double(index) / Double(count - 1)) : 0
                return Ride.RoutePoint(
                    latitude: gp.latitude,
                    longitude: gp.longitude,
                    altitude: 0,
                    timestamp: t,
                    speed: ride.avgSpeedMph,
                    heartRate: nil
                )
            }
        }

        self.totalDuration = self.routePoints.last?.timestamp ?? Double(ride.durationSeconds)

        if let first = self.routePoints.first {
            currentSpeed = first.speed
            currentElevation = first.altitude * 3.28084
            currentHeartRate = first.heartRate
        }
    }

    // MARK: - Playback Controls

    func play() {
        guard !routePoints.isEmpty else { return }
        replayState = .playing
        startTimer()
    }

    func pause() {
        replayState = .paused
        stopTimer()
    }

    func togglePlayPause() {
        switch replayState {
        case .idle, .paused:
            if currentIndex >= routePoints.count - 1 {
                currentIndex = 0
            }
            play()
        case .playing:
            pause()
        }
    }

    func seekTo(progress: Double) {
        let clamped = max(0, min(1, progress))
        let index = Int(clamped * Double(routePoints.count - 1))
        currentIndex = index
        updateCurrentStats()
        updateCamera()
    }

    func cycleSpeed() {
        let allSpeeds = PlaybackSpeed.allCases
        if let idx = allSpeeds.firstIndex(of: playbackSpeed) {
            let next = (idx + 1) % allSpeeds.count
            playbackSpeed = allSpeeds[next]
        }
    }

    func toggleViewMode() {
        viewMode = viewMode == .topDown ? .flyover : .topDown
        updateCamera()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
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
        guard replayState == .playing else { return }
        guard currentIndex < routePoints.count - 1 else {
            pause()
            return
        }

        // Advance based on playback speed
        let currentTimestamp = routePoints[currentIndex].timestamp
        let timeStep = 0.05 * playbackSpeed.rawValue
        let targetTimestamp = currentTimestamp + timeStep

        var newIndex = currentIndex
        while newIndex < routePoints.count - 1 && routePoints[newIndex + 1].timestamp <= targetTimestamp {
            newIndex += 1
        }

        // Always advance at least one frame if we're stuck
        if newIndex == currentIndex && currentIndex < routePoints.count - 1 {
            newIndex = currentIndex + 1
        }

        currentIndex = newIndex
        updateCurrentStats()
        updateCamera()
    }

    // MARK: - Stats Update

    private func updateCurrentStats() {
        guard currentIndex < routePoints.count else { return }
        let pt = routePoints[currentIndex]
        currentSpeed = pt.speed
        currentElevation = pt.altitude * 3.28084
        currentHeartRate = pt.heartRate
        currentTime = pt.timestamp

        // Calculate cumulative distance up to current index
        var dist: Double = 0
        for i in 1...max(1, currentIndex) {
            guard i < routePoints.count else { break }
            let prev = CLLocation(latitude: routePoints[i - 1].latitude, longitude: routePoints[i - 1].longitude)
            let curr = CLLocation(latitude: routePoints[i].latitude, longitude: routePoints[i].longitude)
            dist += curr.distance(from: prev) / 1609.344
        }
        currentDistance = dist
    }

    // MARK: - Camera

    private func updateCamera() {
        guard let coord = currentCoordinate else { return }

        switch viewMode {
        case .topDown:
            cameraPosition = .camera(MapCamera(
                centerCoordinate: coord,
                distance: 500,
                heading: 0,
                pitch: 0
            ))
        case .flyover:
            let heading: Double
            if currentIndex < routePoints.count - 1 {
                let next = routePoints[currentIndex + 1]
                let nextCoord = CLLocationCoordinate2D(latitude: next.latitude, longitude: next.longitude)
                heading = bearing(from: coord, to: nextCoord)
            } else if currentIndex > 0 {
                let prev = routePoints[currentIndex - 1]
                let prevCoord = CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude)
                heading = bearing(from: prevCoord, to: coord)
            } else {
                heading = 0
            }

            cameraPosition = .camera(MapCamera(
                centerCoordinate: coord,
                distance: 150,
                heading: heading,
                pitch: 60
            ))
        }
    }

    // MARK: - Helpers

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let x = sin(dLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let radians = atan2(x, y)
        return radians * 180 / .pi
    }

    func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
