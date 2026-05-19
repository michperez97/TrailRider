# TrailRider Bug Review Notes

Date: 2026-04-11

## Readiness

Not ready for a full-confidence trail test yet.

The app builds successfully, but it should only be used for a short controlled shakedown ride with backup tracking enabled. It should not be the sole recorder for a long or important ride yet.

## Main Findings

### 1. Standalone watch rides can be lost on cold launch

- File: `TrailRider/TrailRider/Services/WatchConnectivityService.swift:126`
- File: `TrailRider/TrailRider/Views/Ride/RideView.swift:41`

`didReceiveUserInfo` sets `hasStandaloneRide = true` as soon as the watch transfer arrives. `RideView` only imports that ride if `authViewModel.currentUser?.id` is already available. If the transfer arrives before auth finishes loading, nothing retries after sign-in, so the ride may remain unsaved.

### 2. Paused watch workouts keep recording route points

- File: `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift:157`
- File: `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift:217`
- File: `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift:272`

`pauseWorkout()` stops the timer but does not stop GPS sampling. Route points continue to be collected while paused and are later synced to the phone, which can corrupt the replayed route.

### 3. Watch rides with no usable GPS data are dropped

- File: `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift:272`
- File: `TrailRider/TrailRider/ViewModels/RideViewModel.swift:217`

`syncRideToPhone()` returns early if `recordedLocations` is empty, and `saveStandaloneWatchRide()` requires `routeCoordinates`. That means a valid workout with distance/calories but denied location permission or weak GPS may never be saved.

## Build Status

This command succeeded:

```bash
xcodebuild -project TrailRider/TrailRider.xcodeproj -scheme TrailRider -destination 'generic/platform=iOS Simulator' build
```

## Test Coverage Note

Automated test coverage is minimal:

- `TrailRiderTests.swift` is effectively a placeholder
- UI tests only launch the app

These issues are not currently protected by tests.

## Practical Recommendation

Current recommendation:

- OK for a short 15-30 minute shakedown on a familiar trail
- Use Apple Workouts, Strava, Garmin, or similar in parallel
- Do not rely on this app alone for a long ride or a ride where losing the track would matter

## Next Session Priorities

1. Make watch ride import retry after auth becomes available
2. Stop or ignore GPS sampling while a workout is paused
3. Allow standalone watch rides to save even when route data is empty
