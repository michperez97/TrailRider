# Ride Replay System — Design Spec

**Date:** 2026-04-03
**Scope:** Ride replay with map playback, 3D flyover, and ghost ride mode

---

## Overview

Three replay modes for recorded rides:

1. **Map Playback** — Top-down animated replay from ride history
2. **3D Flyover** — Cinematic chase-cam replay with terrain elevation and GPS-altitude route line
3. **Ghost Ride** — Live ghost dot during a new ride showing previous pace

## 1. Map Playback

### Access
- Ride History → Tap a ride → Ride Detail screen → "Replay" button

### Behavior
- Full-screen satellite map showing the complete route (dimmed)
- Animated rider dot moves along the route at configurable speed: 2x, 5x, 10x, 20x
- The route behind the dot is highlighted in neon green; route ahead is dimmed
- Stats update in real-time as the dot moves:
  - Speed at that point (from recorded data)
  - Distance covered so far
  - Elapsed time at that point
  - Elevation at that point
  - Heart rate at that point (if Watch data was recorded)
- Scrub bar at the bottom: drag to jump to any moment in the ride
- Play/pause button
- Speed selector (2x / 5x / 10x / 20x)
- Camera follows the dot, keeping it centered

### Data Requirements
- Each ride already stores `routePolyline` (array of GeoPoints) and `durationSeconds`
- Need to also store timestamps per coordinate for accurate speed replay
- For rides that don't have per-point timestamps, interpolate evenly across duration

## 2. 3D Flyover

### Access
- Same screen as Map Playback — toggle button switches between top-down and 3D flyover
- Also accessible from Trail Card → "Flyover" for featured trails

### Behavior
- MapKit `.imagery(elevation: .realistic)` for terrain landscape
- Route polyline rendered at recorded GPS altitude — the trail line rises on climbs and drops on descents
- Camera positioned behind and above the rider dot:
  - Distance behind: ~50m
  - Height above route: ~30m
  - Pitch: ~60° (looking forward along the trail)
  - Heading: follows route direction (computed from next 2-3 points)
- Same speed controls and scrub bar as Map Playback
- Stats overlay: same floating glass badges as active ride (speed, elevation, HR)
- Smooth camera transitions using MapKit animation

### Route Altitude Rendering
- Use MapKit's `MapPolyline` with the route coordinates
- MapKit `.realistic` elevation provides the terrain mesh
- The route polyline uses recorded GPS altitude data for vertical positioning
- This creates a line that follows the actual trail — rising over hills, dropping into valleys
- Where GPS altitude is noisy, apply a simple moving-average smoothing (5-point window)

## 3. Ghost Ride

### Access
- Pre-ride screen: if starting a ride on a trail you've ridden before, option appears: "Race your last ride"
- Trail Card: "Ghost Ride" button (starts a new ride with ghost enabled)

### Behavior
- During an active ride, a second dot (ghost) appears on the map
- Ghost dot is semi-transparent amber/gold, pulsing gently
- Ghost moves along the previous ride's route at the original pace
- Ghost uses real timestamps from the previous ride (or interpolated if not available)
- The rider can see if they're ahead or behind the ghost
- Small badge shows: "Ghost: +0:23 ahead" or "Ghost: -0:15 behind"
- Delta calculated by comparing distance covered at the same elapsed time
- Ghost data loaded from the most recent ride on the same trail (matched by proximity of start point)
- Ghost can be dismissed mid-ride with a tap on the ghost badge

### Trail Matching
- Match rides to trails by comparing the first GPS coordinate:
  - Within 200m of a featured trail's trailhead → match to that trail
  - Within 200m of a previous ride's start point → match to that ride
- Show the most recent ride as the default ghost, with option to pick a different one

---

## Data Model Changes

### RideCoordinate (new model or extension of existing route storage)

Currently rides store `routePolyline: [GeoPoint]` — just lat/lon pairs. For replay we need:

```
routePoints: [
    { latitude, longitude, altitude, timestamp, speed, heartRate }
]
```

**Migration approach:**
- New rides: store full `routePoints` array alongside the existing `routePolyline`
- Old rides: `routePoints` is nil, replay falls back to interpolation from `routePolyline` + `durationSeconds`
- `routePolyline` kept for backward compatibility (map drawing)

### Ride Model Addition

Add to `Ride`:
```swift
var routePoints: [RoutePoint]?  // nil for legacy rides

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double      // meters, from GPS
    let timestamp: Double     // seconds since ride start
    let speed: Double         // m/s at this point
    let heartRate: Double?    // bpm, nil if no Watch
}
```

---

## New Views

### RideReplayView
- Full-screen map with replay controls
- Toggle: 2D (top-down) ↔ 3D (flyover)
- Speed selector: 2x / 5x / 10x / 20x
- Scrub bar with play/pause
- Stats overlay badges (same style as active ride)
- Uses ride-mode color palette

### Ghost Badge (overlay on ActiveRideView)
- Small frosted glass badge showing ghost delta time
- Tap to dismiss ghost
- Positioned below the HR badge on the right side

---

## Screen Layout: Replay View

```
┌──────────────────────────────┐
│ [←Back]              [2D|3D] │  ← top bar
│                              │
│                              │
│  [Speed: 12.4]    [HR: 156] │  ← floating badges
│                              │
│         (MAP)                │
│      ● ────────→             │  ← animated dot on route
│                              │
│                              │
│                              │
├──────────────────────────────┤
│  ◀◀  ▶/⏸  ▶▶   [5x ▾]     │  ← playback controls
│  ═══════●════════════════    │  ← scrub bar
│  00:12:34 / 00:47:23        │  ← time position / total
└──────────────────────────────┘
```

---

## Implementation Priority

1. **RoutePoint data model** — Add to Ride model, start recording in RideViewModel
2. **Map Playback (2D)** — RideReplayView with animated dot, speed controls, scrub bar
3. **3D Flyover** — Add 3D camera mode to RideReplayView with altitude-rendered route
4. **Ghost Ride** — Ghost dot overlay on ActiveRideView, trail matching, delta badge

---

## Out of Scope
- Sharing replays as video
- Comparing two past rides side-by-side
- Segment-level replay (only full rides)
- Multiplayer ghost (racing against friends)
