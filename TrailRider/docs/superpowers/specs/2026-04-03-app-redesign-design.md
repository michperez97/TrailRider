# TrailRider App Redesign — Design Spec

**Date:** 2026-04-03
**Scope:** Watch sync, UI overhaul, trail mapping tool, GPS view enhancements
**Target parks:** Amelia Earhart Park, Virginia Key (Miami, FL)

---

## 1. Watch ↔ Phone Sync

### Behavior: Simple Mirror
- Stopping a ride on either device stops both.
- Phone sends `rideEnded` message to Watch when `stopRide()` is called.
- Watch sends `workoutEnded` to phone when user taps Stop (already works).
- Watch shows its own basic summary after stopping: duration, distance, avg HR, calories.

### Standalone Watch
- Watch can start a workout without the phone nearby.
- GPS sampled every 5 seconds (battery-conscious, good enough for route shape).
- Workout data stored locally: start/end time, duration, distance, calories, HR, GPS coordinates.
- When phone reconnects, ride syncs via `WCSession.transferUserInfo` (reliable background delivery).
- Phone saves it as a normal Ride in Firestore with route polyline.

### Screen Wake Lock
- `UIApplication.shared.isIdleTimerDisabled = true` when ride is active, restored on stop.
- User toggle in profile/settings: "Keep screen on during rides" (default: on).

---

## 2. UI Overhaul

### Aesthetic: "Trail Instrument"
Matte earth base + high-vis accents. Feels like MTB gear — precision instrument built for dirt. Inspired by the look and feel of mountain bike gear: matte frame coatings, knurled grips, high-vis safety colors on pedals and jerseys.

### Color System
| Role | Color | Hex |
|------|-------|-----|
| Base | Matte charcoal/olive | `#0a0c09` to `#0d100c` |
| Trail line | Neon green (glow) | `#00FF88` |
| Speed (hero metric) | Amber | `#D4A574` |
| Heart rate | Terracotta | `#E07A5F` |
| Elevation | Orange | `#FF8800` |
| Distance | Neon green | `#00FF88` |
| Time / secondary | Warm stone | `#9B9B88` |
| Labels / borders | Dark olive | `#3a4030` / `#1e2418` |

### Active Ride Layout
- Map takes ~70% of screen, full edge-to-edge.
- Default satellite map, one-tap toggle button to dark topographic (contour lines).
- Neon green glowing trail line showing recorded route.
- Rider position as pulsing green dot.
- Floating frosted glass overlays on the map:
  - Top-left: Speed (amber, large)
  - Top-right: HR badge (terracotta, compact)
  - Bottom-center: Duration (stone, monospace)
- Compact stats bar docked at bottom edge: Distance | Elevation | Avg Speed | Max Speed
- Tab bar hidden during ride.

### Two-Mode Aesthetic
- **Riding mode:** Full tactical intensity — high-vis accents, dark surfaces, glowing elements.
- **Browsing mode (Home, Trails, Social, Profile):** Same palette but toned down — softer accents, warmer tones, more readable text. Earth-forward, not neon-forward.

---

## 3. Trail Mapping Tool

### Purpose
Admin/creator tool for building and refining featured trail routes at Amelia Earhart Park and Virginia Key. Full toolchain: ride to capture, then edit to perfect.

### Phase 1: GPS Trace Capture
- Ride the actual trail with GPS recording (uses existing ride tracking).
- After ride completes, new option: "Use as Trail Data" alongside the normal ride summary.
- Imports the GPS trace as a raw route — all coordinates, timestamps, speed at each point.
- Stored as a "trail draft" linked to a park.

### Phase 2: Visual Route Editor
- Full satellite map view of the park showing all existing routes + the new GPS trace.
- **Waypoint editing:** Tap any point on the route to select it, drag to reposition. Handles appear on the selected point.
- **Add waypoints:** Tap between two existing points to insert a new one.
- **Delete waypoints:** Long-press a waypoint to remove it (route reconnects through neighbors).
- **GPS jitter cleanup:** "Smooth" button that applies a basic averaging filter to remove noise (especially at stops/trailheads where GPS wanders).
- **Trim:** Drag start/end handles to cut off the approach ride to/from the trailhead.
- **Undo/redo:** Step back through edits.

### Phase 3: Segment Splitter
- View the full cleaned route on the map.
- Tap the route at a split point to slice it into named segments.
- Each segment gets: name, difficulty level, color assignment.
- Segments display as the color-coded routes already shown in `TrailMapView`.
- Preview mode: see how the segments will look in the actual trail card.

### Data Flow
1. GPS trace → raw draft (Firestore or local).
2. Editor saves refined coordinates back to draft.
3. Segments defined on top of the refined route.
4. "Publish" pushes the segments into the featured trail's route data, replacing old hand-placed coordinates.
5. `TrailMapData.swift` hardcoded data eventually migrated to Firestore so edits persist without app updates.

### Editor Screen Layout
- Full-screen satellite map (same style as active ride).
- Toolbar at bottom: Smooth | Trim | Split | Undo | Redo.
- Route drawn with editable waypoint handles (green dots on the line).
- Selected segment highlights, unselected segments dim.
- Segment list panel (slide up from bottom): name, difficulty picker, color, delete.

---

## 4. GPS View Enhancements

### Map Zoom Modes
- **Standard view** (default): Camera follows rider from ~500m altitude. Good overview of route and surroundings.
- **Close-up view:** Camera drops to ~50-100m altitude. See trail detail, individual turns, terrain features. One-tap toggle button on map.
- **Pinch-to-zoom:** Manual zoom that stays locked on rider position. Camera re-centers on movement but respects the user's zoom level.
- **Auto-zoom option:** Zooms in when speed drops (technical sections) and out when speed increases (fire roads/descents).

### Steep Grade Indicator
- Live grade percentage displayed as a badge on the map (near elevation stat).
- Calculated from GPS altitude change over last ~10 meters of distance.
- Color-coded: green (0-5%), yellow (5-10%), orange (10-15%), red (15%+).
- Arrow direction: up arrow for climbing, down arrow for descending.
- Shows in the stats bar: `▲ 12%` or `▼ 8%`.

### Upcoming Curve Warnings
- Only works on mapped/known trails (ones you've ridden before or featured trails).
- App compares rider position to known route, looks 50-100m ahead.
- Detects sharp turns by analyzing angle change between route segments.
- Shows a floating indicator on the map: curve direction arrow (left/right) + severity (gentle/sharp/hairpin).
- Appears ~3-5 seconds before the turn at current speed.
- Fades out after the turn is passed.
- Disabled on unmapped trails (first ride on a new trail).

### Cornering Speed Tracking
- **During ride:** Current speed displayed normally, but the app silently detects curves (angle change > 30° over 20m of route).
- At each detected curve, records: entry speed, minimum speed through the curve, exit speed, curve angle.
- **Post-ride summary:** Ride map shows curves as colored dots — green (fast/smooth), yellow (moderate), red (slow/braking hard).
- Tap a curve dot to see detail: entry/exit/min speed, curve angle.
- Over multiple rides on the same trail: compare cornering speeds to your previous best.

---

## Implementation Priority

1. **Watch sync** — Tightest scope, highest pain point (broken today).
2. **Screen wake lock** — Small, pairs with ride experience.
3. **UI overhaul: Active ride screen** — Map-dominant layout with new color system.
4. **GPS view enhancements** — Zoom modes, grade indicator, curve warnings, cornering speed.
5. **UI overhaul: Browsing mode** — Toned-down version of the palette for non-ride screens.
6. **Trail mapping tool** — Phase 1 (GPS capture), Phase 2 (editor), Phase 3 (segment splitter).

---

## Out of Scope (Future)
- Community trail editing (public-facing editor)
- GPX import/export
- Offline maps
- Elevation profile charts
- Apple Watch standalone trail display
- Segment leaderboards
