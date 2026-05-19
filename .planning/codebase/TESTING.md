---
last_mapped_commit: ea07f7fb52e9ce61ff56007434d01ca377215f1b
---
# Testing

**Analysis Date:** 2026-05-06

## Test Targets

**Unit tests:**
- `TrailRiderTests` in `TrailRider/TrailRiderTests/`.
- `TrailRiderWatch Watch AppTests` in `TrailRider/TrailRiderWatch Watch AppTests/`.

**UI tests:**
- `TrailRiderUITests` in `TrailRider/TrailRiderUITests/`.
- `TrailRiderWatch Watch AppUITests` in `TrailRider/TrailRiderWatch Watch AppUITests/`.

## Frameworks

- Unit tests use Swift Testing with `import Testing`, `@Test`, and `#expect`.
- UI tests use XCTest with `XCTestCase`.
- Some tests import FirebaseFirestore because app models use `GeoPoint` and Firestore Codable types.

## Current Coverage

**Covered:**
- `StandaloneWatchRidePayload` supports missing route coordinates.
- `StandaloneWatchRidePayload` maps valid route coordinate dictionaries and ignores malformed entries.

**Lightly covered or uncovered:**
- `RideViewModel` ride lifecycle and metrics.
- `RideService` Firestore batch write behavior.
- `AuthViewModel` auth routing and onboarding.
- `CommunityTrailService` park/trail/edit/confirmation flows.
- `GroupRideService` session listeners and host authorization.
- `WatchConnectivityService` phone-side message handling.
- `WorkoutManager` HealthKit and WatchConnectivity behavior.
- SwiftUI view rendering and navigation flows beyond generated UI test shell.

## Test Commands

**List project targets and schemes:**
```bash
xcodebuild -list -project TrailRider/TrailRider.xcodeproj
```

**Build app scheme:**
```bash
xcodebuild -project TrailRider/TrailRider.xcodeproj -scheme TrailRider -configuration Debug build
```

**Run app tests:**
```bash
xcodebuild test -project TrailRider/TrailRider.xcodeproj -scheme TrailRider -destination 'platform=iOS Simulator,name=iPhone 16'
```

Destination names should be adjusted to installed simulators. The repo currently targets iOS/watchOS 26.2, so use compatible local runtimes.

## Test Patterns

- Prefer testing pure conversion logic in model/helper types first, as done in `TrailRider/TrailRiderTests/TrailRiderTests.swift`.
- For Firestore-dependent services, add protocol seams or emulator-backed tests before asserting persistence behavior.
- For view models, isolate service dependencies where possible; current singletons make direct unit tests harder.
- For WatchConnectivity and HealthKit, test payload conversion separately from Apple framework session behavior.

## Recommended Next Tests

- Add tests for `StandaloneWatchRidePayload` max speed, elevation gain, start/end time validation, and invalid distance handling.
- Add `RideViewModel.saveStandaloneWatchRide` tests with a mocked ride service once service injection exists.
- Add `RideHistoryViewModel` reload tests around stale cache behavior noted in `TrailRider/docs/TODO.md`.
- Add tests for `RideService.deleteRide` authorization checks against current Firebase user.
- Add tests for `GroupSession.generateCode` uniqueness/format and join/start authorization.
- Add UI smoke tests for sign-in routing, onboarding, ride tab entry, and profile history navigation.

## Fixtures And Sensitive Data

- Do not commit real Firebase plist contents or environment secrets as fixtures.
- Use synthetic dictionaries for watch ride payload tests.
- Prefer static test values for coordinates and distances; current tests use Miami-area sample coordinates.

## Known Test Gaps From Repo Docs

- `TrailRider/docs/RIDE_PIPELINE_AUDIT.md` identifies ride save/view edge cases that are not all represented in tests.
- `TrailRider/docs/TODO.md` lists P0 smoke test coverage for start, pause, resume, save, history display, profile total miles, and delete flow.

---

*Testing map: 2026-05-06*
