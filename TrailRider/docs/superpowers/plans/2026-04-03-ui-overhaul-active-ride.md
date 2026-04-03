# UI Overhaul: Active Ride Screen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the active ride screen with a map-dominant layout, earth/high-vis MTB gear aesthetic, floating glass stat overlays, neon green trail line, satellite/topo map toggle, and screen wake lock.

**Architecture:** Replace `ActiveRideView.swift` with a new map-dominant layout. Extend `ThemeColors.swift` with new ride-mode colors. Add a `MapStyleToggle` control and `RideOverlayBadge` component. Add idle timer management to `RideViewModel`. Keep the existing `RideViewModel` data flow — only the view layer and colors change.

**Tech Stack:** SwiftUI, MapKit, CoreLocation, UIKit (`UIApplication.isIdleTimerDisabled`)

---

### Task 1: Extend Theme Colors for Ride Mode

**Files:**
- Modify: `TrailRider/Theme/ThemeColors.swift`

- [ ] **Step 1: Add ride-mode colors to the Color extension**

Add these colors after the existing `trPrimaryDarker` definition (line 20):

```swift
    // Ride Mode — High-Vis Accents
    static let trRideBase = Color(red: 0x0a/255, green: 0x0c/255, blue: 0x09/255)           // #0a0c09
    static let trRideBaseLighter = Color(red: 0x0d/255, green: 0x10/255, blue: 0x0c/255)     // #0d100c
    static let trRideSurface = Color(red: 0x11/255, green: 0x13/255, blue: 0x10/255)         // #111310
    static let trRideBorder = Color(red: 0x1e/255, green: 0x24/255, blue: 0x18/255)          // #1e2418
    static let trRideTrail = Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)           // #00FF88
    static let trRideSpeed = Color(red: 0xD4/255, green: 0xA5/255, blue: 0x74/255)           // #D4A574 (same as trAccent)
    static let trRideElevation = Color(red: 0xFF/255, green: 0x88/255, blue: 0x00/255)       // #FF8800
    static let trRideHR = Color(red: 0xE0/255, green: 0x7A/255, blue: 0x5F/255)              // #E07A5F (same as trDestructive)
    static let trRideStone = Color(red: 0x9B/255, green: 0x9B/255, blue: 0x88/255)           // #9B9B88
    static let trRideLabel = Color(red: 0x3a/255, green: 0x40/255, blue: 0x30/255)           // #3a4030
```

- [ ] **Step 2: Add ShapeStyle extensions for the new colors**

Add inside the existing `ShapeStyle` extension:

```swift
    static var trRideBase: Color { .trRideBase }
    static var trRideBaseLighter: Color { .trRideBaseLighter }
    static var trRideSurface: Color { .trRideSurface }
    static var trRideBorder: Color { .trRideBorder }
    static var trRideTrail: Color { .trRideTrail }
    static var trRideSpeed: Color { .trRideSpeed }
    static var trRideElevation: Color { .trRideElevation }
    static var trRideHR: Color { .trRideHR }
    static var trRideStone: Color { .trRideStone }
    static var trRideLabel: Color { .trRideLabel }
```

- [ ] **Step 3: Build and verify no compile errors**

Run: Xcode build (Cmd+B)
Expected: Build succeeds, no errors.

- [ ] **Step 4: Commit**

```bash
git add TrailRider/Theme/ThemeColors.swift
git commit -m "feat: add ride-mode high-vis color palette"
```

---

### Task 2: Add Screen Wake Lock to RideViewModel

**Files:**
- Modify: `TrailRider/ViewModels/RideViewModel.swift`

- [ ] **Step 1: Import UIKit at the top of RideViewModel.swift**

Add after the existing imports (line 4):

```swift
import UIKit
```

- [ ] **Step 2: Add keepScreenOn property and idle timer management**

Add a new public property after `isWatchConnected` (around line 39):

```swift
    var keepScreenOn: Bool = true
```

- [ ] **Step 3: Enable idle timer disable in startRide()**

Add as the first line inside `startRide()`, before `locationService.requestAlwaysPermission()`:

```swift
        if keepScreenOn {
            UIApplication.shared.isIdleTimerDisabled = true
        }
```

- [ ] **Step 4: Restore idle timer in stopRide() and discardRide()**

Add as the first line inside `stopRide(userId:)`, before `stopTimer()`:

```swift
        UIApplication.shared.isIdleTimerDisabled = false
```

Add the same line as the first line inside `discardRide()`:

```swift
        UIApplication.shared.isIdleTimerDisabled = false
```

- [ ] **Step 5: Also restore in resetRide() as a safety net**

Add at the end of `resetRide()`:

```swift
        UIApplication.shared.isIdleTimerDisabled = false
```

- [ ] **Step 6: Build and verify**

Run: Xcode build (Cmd+B)
Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add TrailRider/ViewModels/RideViewModel.swift
git commit -m "feat: add screen wake lock during active rides"
```

---

### Task 3: Add Map Style Toggle to RideViewModel

**Files:**
- Modify: `TrailRider/ViewModels/RideViewModel.swift`

- [ ] **Step 1: Add map style enum and property**

Add a new enum inside `RideViewModel`, after the `RideState` enum (around line 16):

```swift
    enum MapStyle: String, CaseIterable {
        case satellite
        case topographic
    }
```

Add a new public property after `cameraPosition` (around line 31):

```swift
    var mapStyleSelection: MapStyle = .satellite
```

- [ ] **Step 2: Build and verify**

Run: Xcode build (Cmd+B)
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add TrailRider/ViewModels/RideViewModel.swift
git commit -m "feat: add map style enum for satellite/topo toggle"
```

---

### Task 4: Create Floating Overlay Badge Component

**Files:**
- Create: `TrailRider/Theme/RideOverlayBadge.swift`

- [ ] **Step 1: Create the RideOverlayBadge view**

Create `TrailRider/Theme/RideOverlayBadge.swift`:

```swift
import SwiftUI

struct RideOverlayBadge<Content: View>: View {
    let borderColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.85))
            .background(Color.trRideBase.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor.opacity(0.2), lineWidth: 1)
            )
    }
}
```

- [ ] **Step 2: Build and verify**

Run: Xcode build (Cmd+B)
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add TrailRider/Theme/RideOverlayBadge.swift
git commit -m "feat: add RideOverlayBadge frosted glass component"
```

---

### Task 5: Rewrite ActiveRideView with Map-Dominant Layout

**Files:**
- Modify: `TrailRider/Views/Ride/ActiveRideView.swift`

- [ ] **Step 1: Replace the entire ActiveRideView.swift with the new layout**

Replace the full contents of `ActiveRideView.swift` with:

```swift
import SwiftUI
import MapKit

struct ActiveRideView: View {
    @Bindable var rideVM: RideViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            // Full-screen map
            mapLayer

            // Floating overlays
            VStack {
                // Top row: Speed (left) + HR (right)
                HStack(alignment: .top) {
                    speedBadge
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        hrBadge
                        mapStyleToggle
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 60)

                Spacer()

                // Bottom: Stats bar + Controls
                bottomPanel
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Map Layer

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $rideVM.cameraPosition) {
            // Route polyline — neon green with glow
            if rideVM.routeCoordinates.count > 1 {
                MapPolyline(coordinates: rideVM.routeCoordinates)
                    .stroke(.trRideTrail, lineWidth: 4)
            }
            UserAnnotation()
        }
        .mapStyle(rideVM.mapStyleSelection == .satellite
            ? .imagery(elevation: .realistic)
            : .standard(elevation: .realistic, emphasis: .muted))
        .mapControls {
            MapCompass()
        }
    }

    // MARK: - Speed Badge

    private var speedBadge: some View {
        RideOverlayBadge(borderColor: .trRideSpeed) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(rideVM.formattedSpeed)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.trRideSpeed)
                    .contentTransition(.numericText())
                    .animation(.default, value: rideVM.formattedSpeed)
                Text("MPH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.trRideSpeed.opacity(0.5))
            }
        }
    }

    // MARK: - Heart Rate Badge

    @ViewBuilder
    private var hrBadge: some View {
        if rideVM.heartRate > 0 {
            RideOverlayBadge(borderColor: .trRideHR) {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.trRideHR)
                        .symbolEffect(.pulse, isActive: true)
                    Text("\(Int(rideVM.heartRate))")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.trRideHR)
                        .contentTransition(.numericText())
                }
            }
        } else if !rideVM.isWatchConnected {
            RideOverlayBadge(borderColor: .trRideLabel) {
                HStack(spacing: 4) {
                    Image(systemName: "applewatch.slash")
                        .font(.caption2)
                    Text("No Watch")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.trRideLabel)
            }
        }
    }

    // MARK: - Map Style Toggle

    private var mapStyleToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                rideVM.mapStyleSelection = rideVM.mapStyleSelection == .satellite
                    ? .topographic : .satellite
            }
        } label: {
            RideOverlayBadge(borderColor: .trRideTrail) {
                Image(systemName: rideVM.mapStyleSelection == .satellite
                    ? "mountain.2.fill" : "globe.americas.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.trRideTrail)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityLabel(rideVM.mapStyleSelection == .satellite
            ? "Switch to topographic map" : "Switch to satellite map")
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Duration
            Text(rideVM.formattedDuration)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.trRideStone)
                .tracking(1)

            // Stats row
            HStack(spacing: 0) {
                rideStat(value: rideVM.formattedDistance, label: "MILES", color: .trRideTrail)
                statDivider
                rideStat(value: rideVM.formattedElevation, label: "ELEV FT", color: .trRideElevation)
                statDivider
                rideStat(value: rideVM.formattedAvgSpeed, label: "AVG MPH", color: .trRideStone)
                if rideVM.activeCalories > 0 {
                    statDivider
                    rideStat(value: String(format: "%.0f", rideVM.activeCalories), label: "CAL", color: .trRideStone)
                }
            }

            // Controls
            HStack(spacing: 40) {
                Button {
                    rideVM.rideState == .riding ? rideVM.pauseRide() : rideVM.resumeRide()
                } label: {
                    Image(systemName: rideVM.rideState == .riding ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(rideVM.rideState == .riding ? Color.trWarning : Color.trRideTrail)
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }
                .accessibilityLabel(rideVM.rideState == .riding ? "Pause Ride" : "Resume Ride")
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: rideVM.rideState)

                Button {
                    rideVM.stopRide(userId: authViewModel.currentUser?.id)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(.trDestructive)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .accessibilityLabel("Stop Ride")
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

    private func rideStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(.trRideLabel)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.trRideBorder)
            .frame(width: 1, height: 30)
    }
}
```

- [ ] **Step 2: Remove the old StatColumn struct**

The old `StatColumn` struct at the bottom of the file is no longer needed. The new code uses the inline `rideStat` helper instead. If `StatColumn` is used elsewhere, keep it; otherwise it is only used in this file and can be removed. The new file above does not include it.

- [ ] **Step 3: Build and verify**

Run: Xcode build (Cmd+B)
Expected: Build succeeds. No references to `StatColumn` elsewhere (it was only used in `ActiveRideView`).

- [ ] **Step 4: Test on simulator**

1. Run the app on iPhone simulator.
2. Navigate to Ride tab → Start Solo Ride.
3. Verify: Full-screen satellite map with neon green trail line.
4. Verify: Speed badge (amber) floats top-left.
5. Verify: HR badge or "No Watch" floats top-right.
6. Verify: Map style toggle button below HR badge.
7. Tap the toggle → map switches to standard (topo-ish) style.
8. Verify: Bottom panel has duration, stats row (distance/elev/avg), and pause/stop controls.
9. Verify: Tab bar is hidden.
10. Verify: Screen does not sleep during the ride.

- [ ] **Step 5: Commit**

```bash
git add TrailRider/Views/Ride/ActiveRideView.swift
git commit -m "feat: redesign ActiveRideView with map-dominant earth/high-vis layout"
```

---

### Task 6: Update RideSummaryView with New Color Palette

**Files:**
- Modify: `TrailRider/Views/Ride/RideSummaryView.swift`

- [ ] **Step 1: Update the route polyline color**

In `RideSummaryView.swift`, change line 15:

```swift
// Old:
.stroke(.trPrimary, lineWidth: 4)

// New:
.stroke(.trRideTrail, lineWidth: 4)
```

- [ ] **Step 2: Update the map style to satellite**

After the `.stroke` line, find the closing of the `Map` block and add a map style. Change:

```swift
                    Map {
                        MapPolyline(coordinates: rideVM.routeCoordinates)
                            .stroke(.trRideTrail, lineWidth: 4)
                    }
                    .frame(height: 250)
```

to:

```swift
                    Map {
                        MapPolyline(coordinates: rideVM.routeCoordinates)
                            .stroke(.trRideTrail, lineWidth: 4)
                    }
                    .mapStyle(.imagery(elevation: .realistic))
                    .frame(height: 250)
```

- [ ] **Step 3: Update stat card glow colors**

Change each `ThemeStatCard` to use appropriate ride-mode colors:

```swift
ThemeStatCard(title: "Distance", value: "\(rideVM.formattedDistance) mi", icon: "road.lanes", glowColor: .trRideTrail, animationDelay: 0.0)
ThemeStatCard(title: "Duration", value: rideVM.formattedDuration, icon: "clock.fill", glowColor: .trRideStone, animationDelay: 0.1)
ThemeStatCard(title: "Avg Speed", value: "\(rideVM.formattedAvgSpeed) mph", icon: "speedometer", glowColor: .trRideSpeed, animationDelay: 0.2)
ThemeStatCard(title: "Max Speed", value: "\(rideVM.formattedMaxSpeed) mph", icon: "gauge.with.dots.needle.67percent", glowColor: .trRideElevation, animationDelay: 0.3)
ThemeStatCard(title: "Elevation", value: "\(rideVM.formattedElevation) ft", icon: "mountain.2.fill", glowColor: .trRideElevation, animationDelay: 0.4)
```

- [ ] **Step 4: Build and verify**

Run: Xcode build (Cmd+B)
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add TrailRider/Views/Ride/RideSummaryView.swift
git commit -m "feat: update RideSummaryView with ride-mode colors and satellite map"
```

---

### Task 7: Verify End-to-End Ride Flow

**Files:** None (testing only)

- [ ] **Step 1: Full ride flow test on simulator**

1. Launch app → Ride tab → Start Solo Ride
2. Confirm: satellite map, neon green route, amber speed overlay, controls at bottom
3. Tap map style toggle → confirm map switches style
4. Wait 30+ seconds, move in simulator (Features → Location → Freeway Drive)
5. Verify: speed updates, distance accumulates, trail line draws
6. Tap Pause → confirm: play button appears, timer pauses
7. Tap Resume → confirm: ride continues, no time jump
8. Tap Stop → confirm: RideSummaryView appears with ride-mode colors and satellite map
9. Tap Done → confirm: back to idle pre-ride screen
10. Verify: screen auto-lock re-enabled after ride ends

- [ ] **Step 2: Commit any fixes found during testing**

```bash
git add -A
git commit -m "fix: address issues found during ride flow testing"
```

(Skip this step if no issues found.)
