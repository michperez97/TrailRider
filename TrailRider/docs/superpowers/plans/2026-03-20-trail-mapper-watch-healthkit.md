# Trail Mapper + Watch App + HealthKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three features: (1) Trail Mapper dev tool for GPS trail data collection, (2) Apple Watch companion app with live HR workout sessions, (3) HealthKit integration on iPhone for real-time HR display during rides.

**Architecture:** Trail Mapper is a standalone `#if DEBUG` dev tool with its own ViewModel and View, plus a GPX exporter service. Watch app uses `HKWorkoutSession` + `HKLiveWorkoutBuilder` for live heart rate, streaming data to iPhone via `WCSession`. iPhone receives HR data and displays it on `ActiveRideView` with zone calculations.

**Tech Stack:** SwiftUI, MapKit, HealthKit, WatchKit, WatchConnectivity, CoreLocation

---

## File Structure

### New Files
```
TrailRider/
  Services/GPXExporter.swift          — Converts coordinate arrays to GPX XML, writes to documents dir
  Services/WatchConnectivityService.swift — iPhone-side WCSession: receives HR from Watch
  Services/HealthKitService.swift     — HR zone calculation, HealthKit permissions
  ViewModels/TrailMapperViewModel.swift — GPS session with segment start/end markers
  Views/Ride/TrailMapperView.swift    — Dev tool UI: map, mark buttons, segment list

TrailRiderWatch/                      — New Watch target (user creates in Xcode)
  TrailRiderWatchApp.swift            — @main entry point
  WorkoutManager.swift                — HKWorkoutSession + HKLiveWorkoutBuilder + WCSession sender
  Views/StartView.swift               — Start workout button
  Views/WorkoutView.swift             — Live HR, duration, distance display
  Views/SummaryView.swift             — Post-workout summary
  Info.plist                          — HealthKit usage descriptions
  TrailRiderWatch.entitlements        — HealthKit entitlement
```

### Modified Files
```
TrailRider/
  ViewModels/RideViewModel.swift      — Add HR properties (heartRate, hrZone, calories)
  Views/Ride/ActiveRideView.swift     — Display HR, zone indicator, calories
  Views/Ride/RideView.swift           — Add Trail Mapper button (#if DEBUG)
  App/TrailRiderApp.swift             — Activate WCSession on launch
  Info.plist                          — Add HealthKit usage description
```

---

## Part 1: Trail Mapper Dev Tool

### Task 1: GPX Exporter Service

**Files:**
- Create: `TrailRider/Services/GPXExporter.swift`

- [ ] **Step 1: Create GPXExporter**

```swift
import Foundation
import CoreLocation

struct GPXExporter {
    static func export(segments: [TrailSegmentRecording], to directory: URL) throws -> [URL] {
        var urls: [URL] = []
        for (index, segment) in segments.enumerated() {
            let name = segment.name ?? "segment-\(String(format: "%02d", index + 1))"
            let fileName = "\(name).gpx"
            let fileURL = directory.appendingPathComponent(fileName)
            let gpx = buildGPX(name: name, coordinates: segment.coordinates)
            try gpx.write(to: fileURL, atomically: true, encoding: .utf8)
            urls.append(fileURL)
        }
        return urls
    }

    private static func buildGPX(name: String, coordinates: [(CLLocationCoordinate2D, Date)]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TrailRider">
        <trk>
        <name>\(name)</name>
        <trkseg>
        """
        for (coord, time) in coordinates {
            let iso = ISO8601DateFormatter().string(from: time)
            xml += "\n<trkpt lat=\"\(coord.latitude)\" lon=\"\(coord.longitude)\"><time>\(iso)</time></trkpt>"
        }
        xml += "\n</trkseg>\n</trk>\n</gpx>"
        return xml
    }
}

struct TrailSegmentRecording: Identifiable {
    let id = UUID()
    var name: String?
    var coordinates: [(CLLocationCoordinate2D, Date)]
    var startTime: Date
    var endTime: Date?

    var distanceMiles: Double {
        var total: Double = 0
        for i in 1..<coordinates.count {
            let prev = CLLocation(latitude: coordinates[i-1].0.latitude, longitude: coordinates[i-1].0.longitude)
            let curr = CLLocation(latitude: coordinates[i].0.latitude, longitude: coordinates[i].0.longitude)
            total += curr.distance(from: prev)
        }
        return total / 1609.344
    }

    var durationSeconds: Int {
        guard let end = endTime else { return 0 }
        return Int(end.timeIntervalSince(startTime))
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project TrailRider.xcodeproj -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD"`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add TrailRider/Services/GPXExporter.swift
git commit -m "feat: add GPX exporter service for trail data collection"
```

### Task 2: Trail Mapper ViewModel

**Files:**
- Create: `TrailRider/ViewModels/TrailMapperViewModel.swift`

- [ ] **Step 1: Create TrailMapperViewModel**

```swift
import Foundation
import CoreLocation
import MapKit
import SwiftUI

#if DEBUG
@Observable
@MainActor
final class TrailMapperViewModel {

    enum SessionState: Equatable {
        case idle
        case recording
        case segmentActive
    }

    // MARK: - State
    var sessionState: SessionState = .idle
    var segments: [TrailSegmentRecording] = []
    var allCoordinates: [CLLocationCoordinate2D] = []
    var currentSegmentCoordinates: [(CLLocationCoordinate2D, Date)] = []
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var elapsedSeconds: Int = 0
    var segmentElapsedSeconds: Int = 0
    var exportedURLs: [URL] = []
    var showExportSheet = false
    var exportError: String?

    // MARK: - Private
    private let locationService = LocationService.shared
    private var timer: Timer?
    private var sessionStartTime: Date?
    private var segmentStartTime: Date?
    private var lastLocation: CLLocation?

    // MARK: - Computed
    var currentSegmentNumber: Int {
        segments.count + (sessionState == .segmentActive ? 1 : 0)
    }

    var formattedSessionTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var formattedSegmentTime: String {
        let m = segmentElapsedSeconds / 60
        let s = segmentElapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Session Controls
    func startSession() {
        locationService.requestPermission()
        locationService.startTracking()
        sessionState = .recording
        sessionStartTime = Date()
        segments = []
        allCoordinates = []
        exportedURLs = []
        exportError = nil
        startTimer()
    }

    func endSession() {
        // Close any active segment
        if sessionState == .segmentActive {
            markSegmentEnd()
        }
        stopTimer()
        locationService.stopTracking()
        sessionState = .idle
        exportSegments()
    }

    // MARK: - Segment Controls
    func markSegmentStart() {
        guard sessionState == .recording else { return }
        sessionState = .segmentActive
        segmentStartTime = Date()
        segmentElapsedSeconds = 0
        currentSegmentCoordinates = []
    }

    func markSegmentEnd() {
        guard sessionState == .segmentActive else { return }
        let segment = TrailSegmentRecording(
            coordinates: currentSegmentCoordinates,
            startTime: segmentStartTime ?? Date(),
            endTime: Date()
        )
        segments.append(segment)
        currentSegmentCoordinates = []
        sessionState = .recording
    }

    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        elapsedSeconds += 1
        if sessionState == .segmentActive {
            segmentElapsedSeconds += 1
        }
        recordLocation()
    }

    private func recordLocation() {
        guard let location = locationService.currentLocation else { return }

        // Filter bad accuracy
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 30 else { return }

        // Filter GPS drift (must move > 2m)
        if let last = lastLocation {
            guard location.distance(from: last) > 2 else { return }
        }

        allCoordinates.append(location.coordinate)

        if sessionState == .segmentActive {
            currentSegmentCoordinates.append((location.coordinate, Date()))
        }

        lastLocation = location
    }

    // MARK: - Export
    private func exportSegments() {
        guard !segments.isEmpty else { return }
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let folder = docs.appendingPathComponent("TrailMapper/\(formattedDate())")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            exportedURLs = try GPXExporter.export(segments: segments, to: folder)
            showExportSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return f.string(from: Date())
    }
}
#endif
```

- [ ] **Step 2: Build to verify**
- [ ] **Step 3: Commit**

### Task 3: Trail Mapper View

**Files:**
- Create: `TrailRider/Views/Ride/TrailMapperView.swift`

- [ ] **Step 1: Create TrailMapperView**

Full-screen map with:
- Live GPS track (gray polyline for full track, colored for active segment)
- Big Mark Start / Mark End toggle button
- Completed segments list at bottom
- Session timer + segment timer
- End Session button

- [ ] **Step 2: Build and test on simulator**
- [ ] **Step 3: Commit**

### Task 4: Wire Trail Mapper into RideView

**Files:**
- Modify: `TrailRider/Views/Ride/RideView.swift`

- [ ] **Step 1: Add #if DEBUG Trail Mapper button to PreRideView**

Add a NavigationLink to TrailMapperView, styled with `.trailGhost` button style, only visible in DEBUG builds.

- [ ] **Step 2: Build, launch on sim, verify button appears**
- [ ] **Step 3: Commit**

---

## Part 2: Apple Watch App

### Task 5: Create Watch Target in Xcode

**Manual step — user must do this in Xcode:**

- [ ] **Step 1: In Xcode, File → New → Target → watchOS → App**
  - Product Name: `TrailRiderWatch`
  - Bundle ID: `Crocobyte.TrailRider.watchkitapp`
  - Watch-only App (no separate extension needed on watchOS 10+)
  - Language: Swift, Interface: SwiftUI

- [ ] **Step 2: Verify target created and builds**

### Task 6: Watch Workout Manager

**Files:**
- Create: `TrailRiderWatch/WorkoutManager.swift`

- [ ] **Step 1: Create WorkoutManager with HKWorkoutSession**

Observable class that:
- Requests HealthKit authorization (heart rate, active energy, workout type)
- Starts HKWorkoutSession + HKLiveWorkoutBuilder for cycling
- Collects live heart rate, calories, distance from HKLiveWorkoutBuilderDelegate
- Sends HR data to iPhone via WCSession.sendMessage every 2 seconds
- Exposes: heartRate, activeCalories, elapsedSeconds, isWorkoutActive

- [ ] **Step 2: Add HealthKit entitlement and Info.plist descriptions to Watch target**
- [ ] **Step 3: Build Watch target**
- [ ] **Step 4: Commit**

### Task 7: Watch Views

**Files:**
- Create: `TrailRiderWatch/Views/StartView.swift`
- Create: `TrailRiderWatch/Views/WorkoutView.swift`
- Create: `TrailRiderWatch/Views/SummaryView.swift`
- Modify: `TrailRiderWatch/TrailRiderWatchApp.swift`

- [ ] **Step 1: Create StartView** — Single "Start Ride" button
- [ ] **Step 2: Create WorkoutView** — Live HR (large), duration, calories, pause/end controls
- [ ] **Step 3: Create SummaryView** — Post-workout stats
- [ ] **Step 4: Wire navigation in TrailRiderWatchApp**
- [ ] **Step 5: Build and test on Watch simulator**
- [ ] **Step 6: Commit**

### Task 8: Watch → iPhone Connectivity (Watch Side)

**Files:**
- Modify: `TrailRiderWatch/WorkoutManager.swift`

- [ ] **Step 1: Add WCSession activation in WorkoutManager**
- [ ] **Step 2: Send HR message to iPhone every heartbeat update**

Message format: `["heartRate": Double, "activeCalories": Double, "hrZone": Int]`

- [ ] **Step 3: Build**
- [ ] **Step 4: Commit**

---

## Part 3: HealthKit on iPhone

### Task 9: iPhone Watch Connectivity Service

**Files:**
- Create: `TrailRider/Services/WatchConnectivityService.swift`

- [ ] **Step 1: Create WatchConnectivityService**

Observable singleton that:
- Activates WCSession
- Receives HR messages from Watch
- Exposes: heartRate, activeCalories, hrZone, isWatchConnected

- [ ] **Step 2: Build**
- [ ] **Step 3: Commit**

### Task 10: HealthKit Service (HR Zones)

**Files:**
- Create: `TrailRider/Services/HealthKitService.swift`

- [ ] **Step 1: Create HealthKitService**

Handles:
- HR zone calculation (5 zones based on max HR: 220 - age or user-configured)
- Zone colors and labels
- HealthKit permission requests on iPhone side

- [ ] **Step 2: Build**
- [ ] **Step 3: Commit**

### Task 11: Update RideViewModel with HR Data

**Files:**
- Modify: `TrailRider/ViewModels/RideViewModel.swift`

- [ ] **Step 1: Add HR properties to RideViewModel**

New properties: `heartRate`, `hrZone`, `activeCalories`, `hrZoneColor`, `hrZoneName`
Subscribe to WatchConnectivityService updates in the timer tick.

- [ ] **Step 2: Build**
- [ ] **Step 3: Commit**

### Task 12: Update ActiveRideView with HR Display

**Files:**
- Modify: `TrailRider/Views/Ride/ActiveRideView.swift`

- [ ] **Step 1: Add HR zone indicator and heart rate display**

Show:
- Current HR in large text with heart icon (animated pulse when receiving data)
- HR zone badge (Zone 1-5 with color: gray/blue/green/yellow/red)
- Active calories counter
- "No Watch" indicator when not connected

- [ ] **Step 2: Build, launch on sim**
- [ ] **Step 3: Commit**

### Task 13: Activate WCSession on App Launch

**Files:**
- Modify: `TrailRider/App/TrailRiderApp.swift`

- [ ] **Step 1: Initialize WatchConnectivityService in TrailRiderApp**
- [ ] **Step 2: Add HealthKit usage description to Info.plist**
- [ ] **Step 3: Build full project (both targets)**
- [ ] **Step 4: Commit**
