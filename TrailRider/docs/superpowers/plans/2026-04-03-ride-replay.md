# Ride Replay — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ride replay with 2D map playback, 3D flyover with GPS-altitude route rendering, and ghost ride mode for racing your previous pace.

**Architecture:** Add RoutePoint model for per-coordinate metadata. Record route points during rides alongside existing routePolyline. New RideReplayView with a ReplayEngine that drives animated playback. Ghost mode adds overlay to existing ActiveRideView. All replay state managed by a new RideReplayViewModel.

**Tech Stack:** SwiftUI, MapKit (iOS 17+ MapPolyline, MapCamera), CoreLocation, Firebase Firestore

---

### Task 1: Add RoutePoint Model and Record During Rides

**Files:**
- Modify: `TrailRider/Models/Ride.swift`
- Modify: `TrailRider/ViewModels/RideViewModel.swift`

- [ ] **Step 1: Add RoutePoint struct to Ride.swift**

Add after the `TrailCondition` enum, still inside the `Ride` struct:

```swift
    struct RoutePoint: Codable, Sendable {
        let latitude: Double
        let longitude: Double
        let altitude: Double       // meters
        let timestamp: Double      // seconds since ride start
        let speed: Double          // mph at this point
        let heartRate: Double?     // bpm, nil if no Watch
    }
```

Add an optional property to `Ride` after `routePolyline`:

```swift
    var routePoints: [RoutePoint]?
```

- [ ] **Step 2: Record RoutePoints in RideViewModel during ride**

In `RideViewModel.swift`, add a private array after `routeCoordinates`:

```swift
    var recordedRoutePoints: [Ride.RoutePoint] = []
```

In `updateStats()`, wherever `routeCoordinates.append(location.coordinate)` is called (two places — first point and movement point), also append a RoutePoint:

```swift
                routeCoordinates.append(location.coordinate)
                recordedRoutePoints.append(Ride.RoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    timestamp: Double(elapsedSeconds),
                    speed: currentSpeedMph,
                    heartRate: heartRate > 0 ? heartRate : nil
                ))
```

- [ ] **Step 3: Include routePoints when building the Ride in stopRide()**

In `stopRide(userId:)`, add `routePoints: recordedRoutePoints` to the Ride constructor (after `routePolyline`).

- [ ] **Step 4: Reset recordedRoutePoints**

Add `recordedRoutePoints = []` in `startRide()` resets and `resetRide()`.

- [ ] **Step 5: Commit**

```bash
git add TrailRider/Models/Ride.swift TrailRider/ViewModels/RideViewModel.swift
git commit -m "feat: add RoutePoint model and record per-coordinate metadata during rides"
```

---

### Task 2: Create RideReplayViewModel

**Files:**
- Create: `TrailRider/ViewModels/RideReplayViewModel.swift`

- [ ] **Step 1: Create the replay engine**

```swift
import Foundation
import MapKit

@Observable
@MainActor
final class RideReplayViewModel {

    enum ReplayState: Equatable {
        case idle
        case playing
        case paused
    }

    enum ViewMode: String, CaseIterable {
        case topDown
        case flyover
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

    // Current point stats
    var currentSpeed: Double = 0
    var currentElevation: Double = 0
    var currentHeartRate: Double? = nil
    var currentDistance: Double = 0
    var currentTime: Double = 0

    // MARK: - Data

    let ride: Ride
    let points: [Ride.RoutePoint]
    let totalDuration: Double

    // Pre-computed coordinates for map drawing
    let allCoordinates: [CLLocationCoordinate2D]

    // Progress (0.0 to 1.0)
    var progress: Double {
        guard !points.isEmpty else { return 0 }
        return Double(currentIndex) / Double(points.count - 1)
    }

    var elapsedFormatted: String {
        formatTime(Int(currentTime))
    }

    var totalFormatted: String {
        formatTime(ride.durationSeconds)
    }

    // MARK: - Private

    private var timer: Timer?

    // MARK: - Init

    init(ride: Ride) {
        self.ride = ride

        if let rp = ride.routePoints, !rp.isEmpty {
            self.points = rp
            self.totalDuration = rp.last?.timestamp ?? Double(ride.durationSeconds)
        } else {
            // Legacy ride: interpolate from routePolyline
            let count = ride.routePolyline.count
            let duration = Double(ride.durationSeconds)
            self.points = ride.routePolyline.enumerated().map { i, gp in
                let t = count > 1 ? duration * Double(i) / Double(count - 1) : 0
                return Ride.RoutePoint(
                    latitude: gp.latitude,
                    longitude: gp.longitude,
                    altitude: 0,
                    timestamp: t,
                    speed: ride.avgSpeedMph,
                    heartRate: nil
                )
            }
            self.totalDuration = duration
        }

        self.allCoordinates = self.points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    // MARK: - Controls

    func play() {
        replayState = .playing
        startTimer()
    }

    func pause() {
        replayState = .paused
        stopTimer()
    }

    func togglePlayPause() {
        if replayState == .playing { pause() } else { play() }
    }

    func seekTo(progress: Double) {
        let index = Int(progress * Double(points.count - 1))
        currentIndex = max(0, min(index, points.count - 1))
        updateCurrentStats()
        updateCamera()
    }

    func cycleSpeed() {
        let all = PlaybackSpeed.allCases
        guard let idx = all.firstIndex(of: playbackSpeed) else { return }
        playbackSpeed = all[(idx + 1) % all.count]
    }

    func toggleViewMode() {
        viewMode = viewMode == .topDown ? .flyover : .topDown
        updateCamera()
    }

    // MARK: - Timer

    private func startTimer() {
        // Tick every 50ms for smooth animation
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard currentIndex < points.count - 1 else {
            pause()
            return
        }

        // Advance time based on playback speed
        let currentTimestamp = points[currentIndex].timestamp
        let nextTimestamp = points[currentIndex + 1].timestamp
        let realDelta = nextTimestamp - currentTimestamp
        let scaledDelta = realDelta / playbackSpeed.rawValue

        // If the time between points is very small at this speed, skip ahead
        if scaledDelta < 0.05 {
            currentIndex += 1
        } else {
            currentIndex += 1
        }

        updateCurrentStats()
        updateCamera()
    }

    private func updateCurrentStats() {
        guard currentIndex < points.count else { return }
        let point = points[currentIndex]
        currentSpeed = point.speed
        currentElevation = point.altitude * 3.28084 // meters to feet
        currentHeartRate = point.heartRate
        currentTime = point.timestamp

        // Calculate distance up to this point
        var dist: Double = 0
        for i in 1...currentIndex where i < points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            dist += curr.distance(from: prev)
        }
        currentDistance = dist / 1609.344
    }

    func updateCamera() {
        guard currentIndex < points.count else { return }
        let point = points[currentIndex]
        let coord = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)

        switch viewMode {
        case .topDown:
            cameraPosition = .camera(MapCamera(
                centerCoordinate: coord,
                distance: 500,
                heading: 0,
                pitch: 0
            ))
        case .flyover:
            // Calculate heading from current to next point
            let heading: Double
            if currentIndex + 1 < points.count {
                let next = points[currentIndex + 1]
                heading = Self.bearing(
                    from: coord,
                    to: CLLocationCoordinate2D(latitude: next.latitude, longitude: next.longitude)
                )
            } else if currentIndex > 0 {
                let prev = points[currentIndex - 1]
                heading = Self.bearing(
                    from: CLLocationCoordinate2D(latitude: prev.latitude, longitude: prev.longitude),
                    to: coord
                )
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

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrailRider/ViewModels/RideReplayViewModel.swift
git commit -m "feat: add RideReplayViewModel with playback engine, speed control, 2D/3D modes"
```

---

### Task 3: Create RideReplayView

**Files:**
- Create: `TrailRider/Views/Ride/RideReplayView.swift`

- [ ] **Step 1: Create the replay view**

```swift
import SwiftUI
import MapKit

struct RideReplayView: View {
    @State private var replayVM: RideReplayViewModel

    init(ride: Ride) {
        _replayVM = State(initialValue: RideReplayViewModel(ride: ride))
    }

    var body: some View {
        ZStack {
            mapLayer

            VStack {
                // Top: stats badges
                HStack(alignment: .top) {
                    speedBadge
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        if let hr = replayVM.currentHeartRate, hr > 0 {
                            hrBadge(hr: hr)
                        }
                        viewModeToggle
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 60)

                Spacer()

                // Bottom: playback controls
                playbackPanel
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            replayVM.updateCamera()
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $replayVM.cameraPosition) {
            // Full route (dimmed)
            if replayVM.allCoordinates.count > 1 {
                MapPolyline(coordinates: replayVM.allCoordinates)
                    .stroke(.trRideTrail.opacity(0.25), lineWidth: 3)
            }

            // Traveled route (bright)
            if replayVM.currentIndex > 0 {
                let traveled = Array(replayVM.allCoordinates.prefix(replayVM.currentIndex + 1))
                MapPolyline(coordinates: traveled)
                    .stroke(.trRideTrail, lineWidth: 4)
            }

            // Rider dot
            if replayVM.currentIndex < replayVM.allCoordinates.count {
                Annotation("", coordinate: replayVM.allCoordinates[replayVM.currentIndex]) {
                    Circle()
                        .fill(.trRideTrail)
                        .frame(width: 14, height: 14)
                        .shadow(color: .trRideTrail.opacity(0.5), radius: 6)
                }
            }
        }
        .mapStyle(replayVM.viewMode == .flyover
            ? .imagery(elevation: .realistic)
            : .imagery(elevation: .realistic))
        .mapControls { MapCompass() }
        .animation(.easeInOut(duration: 0.3), value: replayVM.cameraPosition)
    }

    // MARK: - Speed Badge

    private var speedBadge: some View {
        RideOverlayBadge(borderColor: .trRideSpeed) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", replayVM.currentSpeed))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.trRideSpeed)
                    .contentTransition(.numericText())
                Text("MPH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.trRideSpeed.opacity(0.5))
            }
        }
    }

    // MARK: - HR Badge

    private func hrBadge(hr: Double) -> some View {
        RideOverlayBadge(borderColor: .trRideHR) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.trRideHR)
                Text("\(Int(hr))")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.trRideHR)
            }
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.5)) {
                replayVM.toggleViewMode()
            }
        } label: {
            RideOverlayBadge(borderColor: .trRideTrail) {
                Text(replayVM.viewMode == .topDown ? "3D" : "2D")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.trRideTrail)
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .accessibilityLabel(replayVM.viewMode == .topDown
            ? "Switch to 3D flyover" : "Switch to top-down view")
    }

    // MARK: - Playback Panel

    private var playbackPanel: some View {
        VStack(spacing: 10) {
            // Stats row
            HStack(spacing: 0) {
                replayStat(value: String(format: "%.2f", replayVM.currentDistance), label: "MILES", color: .trRideTrail)
                statDivider
                replayStat(value: String(format: "%.0f", replayVM.currentElevation), label: "ELEV FT", color: .trRideElevation)
                statDivider
                replayStat(value: replayVM.elapsedFormatted, label: "TIME", color: .trRideStone)
            }

            // Scrub bar
            Slider(value: Binding(
                get: { replayVM.progress },
                set: { replayVM.seekTo(progress: $0) }
            ), in: 0...1)
            .tint(.trRideTrail)

            // Time labels
            HStack {
                Text(replayVM.elapsedFormatted)
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(.trRideStone)
                Spacer()
                Text(replayVM.totalFormatted)
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(.trRideLabel)
            }

            // Controls row
            HStack(spacing: 30) {
                // Speed selector
                Button {
                    replayVM.cycleSpeed()
                } label: {
                    Text(replayVM.playbackSpeed.label)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.trRideElevation)
                        .frame(width: 44, height: 44)
                        .background(Color.trRideBorder)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Playback speed: \(replayVM.playbackSpeed.label)")

                // Play/Pause
                Button {
                    replayVM.togglePlayPause()
                } label: {
                    Image(systemName: replayVM.replayState == .playing ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(Color.trRideTrail)
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }
                .accessibilityLabel(replayVM.replayState == .playing ? "Pause" : "Play")

                // Placeholder for symmetry
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            Color.trRideSurface.opacity(0.9)
                .background(.ultraThinMaterial)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.trRideBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func replayStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.trRideLabel)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.trRideBorder)
            .frame(width: 1, height: 24)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TrailRider/Views/Ride/RideReplayView.swift
git commit -m "feat: add RideReplayView with 2D/3D toggle, scrub bar, speed controls"
```

---

### Task 4: Add Replay Button to RideDetailView

**Files:**
- Modify: `TrailRider/Views/Profile/RideDetailView.swift`

- [ ] **Step 1: Add a "Replay" navigation link**

After the stats grid (after the `.padding(.horizontal)` on the LazyVGrid), add:

```swift
                    // Replay button
                    if coordinates.count > 1 {
                        NavigationLink(destination: RideReplayView(ride: ride)) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Replay Ride")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.trailPrimary)
                        .padding(.horizontal)
                    }
```

- [ ] **Step 2: Commit**

```bash
git add TrailRider/Views/Profile/RideDetailView.swift
git commit -m "feat: add Replay Ride button to ride detail screen"
```

---

### Task 5: Add Ghost Ride Support

**Files:**
- Modify: `TrailRider/ViewModels/RideViewModel.swift`
- Modify: `TrailRider/Views/Ride/ActiveRideView.swift`

- [ ] **Step 1: Add ghost ride state to RideViewModel**

Add properties after `recordedRoutePoints`:

```swift
    // Ghost ride
    var ghostPoints: [Ride.RoutePoint]?
    var ghostCurrentIndex: Int = 0
    var ghostDelta: String = ""  // "+0:23" or "-0:15"
    var isGhostActive: Bool { ghostPoints != nil }
```

Add method to load ghost data:

```swift
    func loadGhost(from ride: Ride) {
        if let rp = ride.routePoints, !rp.isEmpty {
            ghostPoints = rp
        } else {
            // Legacy: interpolate
            let count = ride.routePolyline.count
            let duration = Double(ride.durationSeconds)
            ghostPoints = ride.routePolyline.enumerated().map { i, gp in
                let t = count > 1 ? duration * Double(i) / Double(count - 1) : 0
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
        ghostCurrentIndex = 0
    }

    func dismissGhost() {
        ghostPoints = nil
        ghostCurrentIndex = 0
        ghostDelta = ""
    }
```

In `tick()`, after `updateHeartRate()`, add:

```swift
        updateGhost()
```

Add the ghost update method:

```swift
    private func updateGhost() {
        guard let ghost = ghostPoints else { return }
        let elapsed = Double(elapsedSeconds)

        // Advance ghost to match elapsed time
        while ghostCurrentIndex < ghost.count - 1 && ghost[ghostCurrentIndex + 1].timestamp <= elapsed {
            ghostCurrentIndex += 1
        }

        // Calculate delta: compare distance at same elapsed time
        let ghostDist: Double
        if ghostCurrentIndex > 0 {
            var d: Double = 0
            for i in 1...ghostCurrentIndex {
                let prev = CLLocation(latitude: ghost[i-1].latitude, longitude: ghost[i-1].longitude)
                let curr = CLLocation(latitude: ghost[i].latitude, longitude: ghost[i].longitude)
                d += curr.distance(from: prev)
            }
            ghostDist = d / 1609.344
        } else {
            ghostDist = 0
        }

        let delta = distanceMiles - ghostDist
        if delta >= 0 {
            ghostDelta = String(format: "+%.2f mi ahead", delta)
        } else {
            ghostDelta = String(format: "%.2f mi behind", delta)
        }
    }
```

In `resetRide()`, add:

```swift
        ghostPoints = nil
        ghostCurrentIndex = 0
        ghostDelta = ""
```

- [ ] **Step 2: Add ghost dot and badge to ActiveRideView**

In `ActiveRideView.swift`, inside the `mapLayer` Map content, after `UserAnnotation()`, add:

```swift
            // Ghost rider dot
            if rideVM.isGhostActive,
               let ghost = rideVM.ghostPoints,
               rideVM.ghostCurrentIndex < ghost.count {
                let gp = ghost[rideVM.ghostCurrentIndex]
                Annotation("Ghost", coordinate: CLLocationCoordinate2D(latitude: gp.latitude, longitude: gp.longitude)) {
                    Circle()
                        .fill(Color.trRideSpeed.opacity(0.6))
                        .frame(width: 12, height: 12)
                        .shadow(color: .trRideSpeed.opacity(0.4), radius: 4)
                }
            }
```

Add a ghost delta badge in the overlay VStack. After `Spacer()` and before `bottomPanel`, add:

```swift
                // Ghost delta badge
                if rideVM.isGhostActive {
                    HStack {
                        Spacer()
                        Button {
                            rideVM.dismissGhost()
                        } label: {
                            RideOverlayBadge(borderColor: .trRideSpeed) {
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.run")
                                        .font(.caption2)
                                    Text(rideVM.ghostDelta)
                                        .font(.caption.bold().monospacedDigit())
                                }
                                .foregroundStyle(.trRideSpeed)
                            }
                        }
                        .padding(.trailing, 14)
                    }
                    .padding(.bottom, 8)
                }
```

- [ ] **Step 3: Commit**

```bash
git add TrailRider/ViewModels/RideViewModel.swift TrailRider/Views/Ride/ActiveRideView.swift
git commit -m "feat: add ghost ride mode with delta badge on active ride"
```
