# Ride Save/View Pipeline Audit — 2026-04-11

Full trace of the ride save → display round-trip. Was performed after commit `b5b305d` introduced atomic batch writes. **Purpose:** establish exactly what works, what's broken, and what to fix before shipping.

## Scope

- How a completed ride gets persisted to Firestore.
- How saved rides are fetched and shown in `RideHistoryView`.
- How a single ride is viewed in `RideDetailView`.
- What guarantees Firestore security rules provide.
- Secondary findings uncovered during the trace (wake lock gap, simulator launch investigation).

## Architecture trace

### Save path (phone-tracked ride, the happy path)

1. `ActiveRideView` "Stop" button → `RideViewModel.stopRide(userId:)`.
2. Junk-ride filter in `RideViewModel.swift:173-174`: `elapsedSeconds > 30 && distanceMiles > 0.01`. Anything shorter or less distance is **silently dropped** — by design, not a bug.
3. Builds a `Ride` struct with userId, start/end time, stats, `routePolyline` (array of `GeoPoint`), and `routePoints` (per-coord metadata for replay).
4. Sets `savedRide = ride`, `isSaving = true`, `saveError = nil`.
5. Spawns `Task { ... }` which calls `rideService.saveRide(ride)`. Because the Task implicitly captures `self` (via `rideService` access), the RideViewModel stays alive until the save completes — so navigating away from the summary screen mid-save is safe.
6. `RideService.saveRide` (`RideService.swift:17-27`) commits a Firestore `WriteBatch`:
   - Pre-allocates a doc ref via `ridesCollection.document()`.
   - `batch.setData(from: ride, forDocument: ref)` — encodes via Codable.
   - `batch.updateData(["totalMiles": FieldValue.increment(ride.distanceMiles)], forDocument: userRef)`.
   - `batch.commit()` — all-or-nothing.
7. On success: `isSaving = false`.
8. `RideView.swift:48-52` has `.onChange(of: rideVM.isSaving) { wasSaving, isSaving in ... }` that catches the falling edge (wasSaving=true, isSaving=false, saveError=nil) and calls `authViewModel.refreshCurrentUser()` to pull fresh `totalMiles` into the profile header.

**Verdict:** correct. Atomic. Safe under navigation. Profile stats update reactively.

### Save path (standalone Watch ride import)

1. Watch-side `WorkoutManager` records a ride and hands the phone a dictionary payload.
2. `RideViewModel.saveStandaloneWatchRide(_:userId:)` (`RideViewModel.swift:217-257`) extracts `startTime`, `endTime`, `durationSeconds`, `distanceMeters`, `routeCoordinates`.
3. Dedup check: `rideService.rideExists(userId:startTime:)`. If it returns `true`, the import bails. If it throws (e.g., missing Firestore composite index), the save proceeds anyway — the fallback comment calls this out: *"better a duplicate than a lost ride."*
4. Builds a `Ride` and calls `rideService.saveRide` → same WriteBatch path as above.

**Verdict:** save path is sound, but two data-loss bugs exist on this path — see Bug #2 and Bug #3.

### Read path

1. `RideHistoryView.swift:42-47` uses `.task { ... }` to trigger load on appear.
2. Guards on `historyVM.rides.isEmpty` — **this is Bug #1**.
3. Calls `historyVM.loadRides(userId:)` → `rideService.getRides(userId:)`.
4. `RideService.getRides` (`RideService.swift:30-36`) runs:
   ```swift
   ridesCollection
     .whereField("userId", isEqualTo: userId)
     .order(by: "startTime", descending: true)
     .getDocuments()
   ```
   Then `compactMap { try? $0.data(as: Ride.self) }`. `@DocumentID` populates `Ride.id` from the Firestore doc ID automatically.
5. `List` renders `RideRow` per ride.
6. Tapping a row pushes `RideDetailView(ride: ride)`. **No second fetch** — the detail view reads from the already-loaded struct.

**Verdict:** query is correct. `@DocumentID` round-trip is correct. Display is correct. The bug is in the **caching gate**, not the query.

### Firestore security rules (`firestore.rules:22-31`)

```
match /rides/{rideId} {
  allow read:   if request.auth != null && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
  allow delete: if request.auth != null && resource.data.userId == request.auth.uid;
  allow update: if false;
}
```

Airtight. Nobody can read, create, or delete another user's rides. **Updates are explicitly denied**, which means if we ever try to edit a ride in place (add conditionReport after the fact, attach photos, etc.), the client will silently fail until rules are relaxed. Keep this in mind for future features.

## Bugs found

### 🔴 Bug #1 — `RideHistoryView` silently caches stale data across tab switches

**File:** `TrailRider/TrailRider/Views/Profile/RideHistoryView.swift:42-47`

**Current code:**
```swift
.task {
    guard historyVM.rides.isEmpty else { return }
    if let userId = authViewModel.currentUser?.id {
        await historyVM.loadRides(userId: userId)
    }
}
```

**Root cause:** `@State private var historyVM = RideHistoryViewModel()` persists for the lifetime of the tab's view, not the lifetime of a single appearance. In a `TabView`, switching away from and back to a tab does not destroy its view hierarchy — the `@State` stays mounted. The `guard ... isEmpty` short-circuits the reload, so a new ride saved in another tab does not appear in history until the app is killed or the view is force-rebuilt.

**Reproduction:**
1. Launch app, go to Profile → History. Rides load, cache populates.
2. Switch to Ride tab, finish a real ride (saves successfully to Firestore).
3. Switch back to Profile → History.
4. **Expected:** new ride at the top of the list.
5. **Actual:** stale list, new ride missing.

**Severity:** P0. Will bite on the first real ride of a session.

**Fix:**
```swift
.task {
    if let userId = authViewModel.currentUser?.id {
        await historyVM.loadRides(userId: userId)
    }
}
.refreshable {
    if let userId = authViewModel.currentUser?.id {
        await historyVM.loadRides(userId: userId)
    }
}
```

Remove the guard (Firestore caches the query locally in 26.2 SDK, so refetches are near-instant). Add `.refreshable` as a user-triggered safety net.

---

### 🔴 Bug #2 — Standalone Watch rides lose max speed and elevation gain

**File:** `TrailRider/TrailRider/ViewModels/RideViewModel.swift:236-249`

**Current code:**
```swift
let ride = Ride(
    userId: userId,
    startTime: startTime,
    endTime: Date(timeIntervalSince1970: endTs),
    durationSeconds: duration,
    distanceMiles: miles,
    maxSpeedMph: 0,           // ← hardcoded
    avgSpeedMph: avg,
    elevationGainFeet: 0,     // ← hardcoded
    ...
)
```

**Root cause:** the watch-payload extraction at lines 218-222 only pulls `startTime`, `endTime`, `duration`, `distanceMeters`, and `routeCoordinates`. Max speed and elevation are never read from the dictionary (and may not even be sent from the watch side).

**Severity:** P0 for Watch users. Every standalone Watch-recorded ride shows `0 mph max speed` and `0 ft elevation` in history. That data is gone — not recoverable after the fact unless `routePoints` were recorded, which on the watch path they are not.

**Fix:**
1. Phone side (`RideViewModel.swift:218-222`): extract `maxSpeedMph` and `elevationGainFeet` from `data`.
2. Watch side (`TrailRiderWatch Watch App/WorkoutManager.swift` or wherever the standalone payload is assembled): ensure those fields are sent. Check what `HKWorkoutSession` exposes — `HKQuantityTypeIdentifier.runningSpeed` / max can give max speed. Elevation is available via `CLLocation.altitude` deltas during recording.

---

### 🟡 Bug #3 — Dedup query needs a Firestore composite index (already in TODO)

**File:** `TrailRider/TrailRider/Services/RideService.swift:62-70`

**Root cause:** the query `whereField("userId" == userId) + whereField("startTime" == startTime)` is compound. Firestore requires a composite index for compound equality queries — the index is not in the repo (`firestore.indexes.json` does not exist at the repo root) and has not been deployed.

**Impact:** first production call to `rideExists` throws `FAILED_PRECONDITION`. Graceful fallback in `RideViewModel.swift:229-231` lets the save proceed, so no data is lost — but **dedup silently doesn't work** until the index is deployed. A re-imported Watch ride can duplicate.

**Severity:** P1. Only bites on the Watch-import path. Fix by adding `firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "rides",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "startTime", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Deploy with `npx firebase-tools deploy --only firestore:indexes`.

---

### 🟡 Bug #4 — `isSaving` / `saveError` write ordering is a landmine

**File:** `TrailRider/TrailRider/ViewModels/RideViewModel.swift:197-204`

**Current code:**
```swift
Task {
    do {
        _ = try await rideService.saveRide(ride)
    } catch {
        saveError = "Failed to save ride: \(error.localizedDescription)"
    }
    isSaving = false
}
```

**Root cause:** `RideView.swift:48-52` watches `isSaving` and checks `saveError == nil` to decide whether to refresh the profile. Today this works because the `catch` sets `saveError` **before** `isSaving = false`. If someone later "cleans up" by moving `isSaving = false` earlier, the `.onChange` will fire with a still-nil `saveError` and trigger an erroneous refresh after a failed save.

**Severity:** P1. Not a current bug; a fragility to pin down.

**Fix:** collapse both fields into a single computed `saveStatus` enum (`.idle / .saving / .saved / .failed(String)`) so ordering can't drift. OR leave a comment on the property declarations explicitly saying "always set saveError before isSaving = false."

---

### 🟢 Bug #5 — `bikeId` and `trailId` never populated

**File:** `TrailRider/TrailRider/ViewModels/RideViewModel.swift:178-192` (and `saveStandaloneWatchRide`)

**Root cause:** `Ride` has optional `bikeId` and `trailId` fields but `stopRide` never sets them. Probably intentional (future feature) but worth knowing when someone asks "why doesn't my ride show which bike I used?"

**Severity:** P3. Not a bug, missing feature.

## Related findings (not save/view pipeline, but uncovered this session)

### Wake lock has a scene-phase gap

**File:** `TrailRider/TrailRider/Views/Ride/ActiveRideView.swift:57-62`

Current implementation:
```swift
.task {
    UIApplication.shared.isIdleTimerDisabled = true
}
.onDisappear {
    UIApplication.shared.isIdleTimerDisabled = false
}
```

**Gap:** `.task` runs once on view appear. It does NOT re-run when the app backgrounds and foregrounds. iOS resets `isIdleTimerDisabled` to `false` on some scene transitions. If a rider pulls their phone out mid-ride, checks something, and the screen locks or the app backgrounds briefly, the wake lock is lost when they come back.

**Also:** Low Power Mode overrides the wake lock entirely — iOS silently ignores `isIdleTimerDisabled = true` when Low Power Mode is on. This is a documented iOS behavior. Worth noting in the user-facing docs.

**Fix:**
```swift
@Environment(\.scenePhase) private var scenePhase
// ...
.onChange(of: scenePhase) { _, phase in
    if phase == .active {
        UIApplication.shared.isIdleTimerDisabled = true
    }
}
```
Re-assert on every `.active` transition.

### Simulator launch investigation (2026-04-11 morning)

**Symptom user reported:** "tried to run the project on the simulator but it's not working" (option 2: build succeeds, simulator launches to blank/white screen).

**Findings:**
- Device build (`b5b305d`) compiles cleanly with only pre-existing warnings. Not a compile issue.
- Booted simulator: **iPhone 17 on iOS 26.2** (`23E69C8F-85B8-43CC-8652-E0548860DCFB`). Matches deployment target (`IPHONEOS_DEPLOYMENT_TARGET = 26.2`).
- **Real bundle ID: `Crocobyte.TrailRider`** (not `com.michper.TrailRider`). See `project.pbxproj:667`.
- SpringBoard logs from 2026-04-11 08:43:18 show the app launched successfully: `taskState: Running; visibility: Foreground`, scene transitioned from `home-screen` to `application`, `running-active-Visible`. **No crash signature**, no ReportCrash, no SIGABRT.
- A couple seconds later at 08:43:20, `DVTInstrumentsFoundation` initiated StoreKit cleanup — signature of Xcode stopping the session (user pressed ⌘.).
- Separately, an `xcodebuild test` process (`PID 26006`) was holding DerivedData lock. First build attempt failed with "database is locked" — this was misleading, unrelated to code. Retry with `-derivedDataPath /tmp/trailrider-verify-build` succeeded.

**Conclusion:** the "blank screen" is not a crash. Most likely the app is rendering but the initial view looks empty (e.g., `RootView` stuck in a loading branch waiting on Firebase auth, or the first view has a white background and no content). **This was never fully resolved** — user pivoted to other topics before we could narrow it down. Next session: get a screenshot of the "blank" screen and check `RootView` / `TrailRiderApp` startup logic.

## Priority order for next session

1. **Fix Bug #1 (RideHistoryView cache)** — 2-line change, biggest user impact, zero risk.
2. **Fix wake lock scene-phase gap** — 5-line change, prevents the screen going to sleep mid-ride.
3. **Resolve the "blank screen on simulator" mystery** — need a screenshot or Xcode console output. Most likely `RootView` is stuck in a loading branch.
4. **Fix Bug #2 (Watch standalone data loss)** — needs both phone-side and watch-side edits. Moderate effort.
5. **Deploy Firestore composite index (Bug #3)** — one JSON file, one CLI command.
6. **Refactor Bug #4 ordering landmine** — cleanup, low urgency.
7. **Wire `bikeId`/`trailId` (Bug #5)** — feature work, scope TBD.

## Session context (for cold pickup)

- Last commit on main: `96d27bb docs: add TODO with trail-ready checklist and follow-ups`.
- Prior commit `b5b305d` introduced Firestore batch writes + dedup. This audit was performed against that code.
- User was planning to ride today (2026-04-11) but the session ended before the blank-screen issue was resolved. **Don't assume the current main is trail-ready until Bug #1 and the blank-screen investigation are closed.**
- User's bundle ID: `Crocobyte.TrailRider`. User's git identity: `michperez97`.
- Project is on iOS 26.2 deployment target, Xcode 26 / iOS 26 SDK, Swift 6 language mode with warnings (not errors).
