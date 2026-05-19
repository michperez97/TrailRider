---
last_mapped_commit: ea07f7fb52e9ce61ff56007434d01ca377215f1b
---
<!-- refreshed: 2026-05-06 -->
# Architecture

**Analysis Date:** 2026-05-06

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│ `TrailRider/TrailRider/Views/` and watch app views            │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
┌─────────────────────────────┐   ┌───────────────────────────┐
│       @Observable VMs        │   │   Singleton platform svcs  │
│ `TrailRider/TrailRider/`     │   │ `LocationService`,         │
│ `ViewModels/`                │   │ `WatchConnectivityService` │
└───────────────┬─────────────┘   └──────────────┬────────────┘
                │                                │
                ▼                                ▼
┌─────────────────────────────────────────────────────────────┐
│                         Services                             │
│ Firebase, CoreLocation, Auth, group rides, community trails   │
│ `TrailRider/TrailRider/Services/`                             │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
┌─────────────────────────────┐   ┌───────────────────────────┐
│    Codable Firestore Models  │   │ Apple platform frameworks │
│ `TrailRider/TrailRider/`     │   │ HealthKit, WatchConnectivity,│
│ `Models/`                    │   │ CoreLocation, MapKit       │
└─────────────────────────────┘   └───────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `TrailRiderApp` | App bootstrap, Firebase configuration, watch activation, Miami park seeding | `TrailRider/TrailRider/App/TrailRiderApp.swift` |
| `RootView` | Auth-state routing to sign-in, onboarding, or main app | `TrailRider/TrailRider/App/RootView.swift` |
| `MainTabView` | Five-tab app shell: Home, Trails, Ride, Social, Profile | `TrailRider/TrailRider/App/MainTabView.swift` |
| `RideViewModel` | Ride lifecycle, metrics, route points, watch ride import, save state | `TrailRider/TrailRider/ViewModels/RideViewModel.swift` |
| `WorkoutManager` | watchOS workout session, HealthKit metrics, GPS sampling, phone sync | `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift` |
| `RideService` | Firestore ride CRUD and atomic total-mile updates | `TrailRider/TrailRider/Services/RideService.swift` |
| `CommunityTrailService` | Draft/published trails, parks, confirmations, edits, seeding | `TrailRider/TrailRider/Services/CommunityTrailService.swift` |
| `GroupRideService` | Group ride session lifecycle and live member listeners | `TrailRider/TrailRider/Services/GroupRideService.swift` |
| `Theme` components | Shared colors, tactile cards, buttons, fields, icons | `TrailRider/TrailRider/Theme/` |

## Pattern Overview

**Overall:** SwiftUI + Observation + service layer + Firestore-backed Codable models.

**Key Characteristics:**
- Views are mostly thin SwiftUI compositions that own or receive `@State` view models.
- View models are `@Observable` and `@MainActor`; they translate service results into UI state.
- Services are `final class ...: Sendable` singletons with computed Firestore references.
- Models are `Codable`, `Identifiable`, and frequently `Sendable`; Firestore IDs use `@DocumentID`.
- The watch app has its own `WorkoutManager` and communicates with the phone app through WatchConnectivity.

## Layers

**App Layer:**
- Entry point: `TrailRider/TrailRider/App/TrailRiderApp.swift`.
- Runtime routing: `TrailRider/TrailRider/App/RootView.swift`.
- App shell: `TrailRider/TrailRider/App/MainTabView.swift`.

**UI Layer:**
- Feature views live in `TrailRider/TrailRider/Views/Auth`, `Home`, `Profile`, `Ride`, `Social`, and `Trails`.
- Theme primitives live in `TrailRider/TrailRider/Theme`.
- Watch UI lives in `TrailRider/TrailRiderWatch Watch App/StartView.swift`, `WorkoutView.swift`, and `SummaryView.swift`.

**State Layer:**
- View models live in `TrailRider/TrailRider/ViewModels`.
- Use `@State` for per-view models and `@Environment(AuthViewModel.self)` for auth context.
- Long-running or platform-callback state is kept in singleton services such as `LocationService` and `WatchConnectivityService`.

**Service Layer:**
- Firebase services own collection names and query shape.
- Platform services wrap CoreLocation and WatchConnectivity delegates.
- Services return domain models and throw errors for view models to surface.

**Data Model Layer:**
- Domain models live in `TrailRider/TrailRider/Models`.
- Firestore encoding uses Codable, `GeoPoint`, `@DocumentID`, subcollections, and transaction/batch APIs.

## Important Data Flows

**Authentication:**
1. `SignInView` drives Apple authorization through `AuthViewModel`.
2. `AuthViewModel` creates a nonce through `AuthService`.
3. `AuthService` signs into Firebase.
4. Auth listener in `AuthViewModel` loads or creates `AppUser` with `UserService`.
5. `RootView` routes based on `.signedOut`, `.onboarding`, or `.signedIn`.

**Phone-tracked ride save:**
1. `RideView` / `ActiveRideView` control `RideViewModel`.
2. `RideViewModel` reads `LocationService` and watch heart-rate state.
3. `RideViewModel.stopRide(userId:)` builds a `Ride`.
4. `RideService.saveRide` writes the ride and increments user total miles in a Firestore batch.

**Standalone watch ride import:**
1. `WorkoutManager` records HealthKit/GPS metrics and syncs a standalone payload.
2. `WatchConnectivityService.session(_:didReceiveUserInfo:)` stores the payload.
3. `RideViewModel.saveStandaloneWatchRide(_:userId:)` converts it through `StandaloneWatchRidePayload`.
4. `RideService.rideExists` deduplicates by user and start time before save.

**Group ride:**
1. `GroupRideViewModel` calls `GroupRideService`.
2. `GroupRideService` creates/join/starts sessions in `groupSessions`.
3. Realtime listeners emit session and member updates through Firestore snapshot listeners.

## Where To Add Code

- New iOS feature screen: add a SwiftUI view under `TrailRider/TrailRider/Views/<Feature>/`.
- New feature state: add an `@Observable @MainActor` view model under `TrailRider/TrailRider/ViewModels/`.
- New Firebase collection access: add methods to an existing service in `TrailRider/TrailRider/Services/` or create a focused `*Service.swift`.
- New shared style: extend `TrailRider/TrailRider/Theme/`.
- New persisted type: add a Codable model under `TrailRider/TrailRider/Models/`.
- New watch behavior: update `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift` and the corresponding iOS `WatchConnectivityService`.

---

*Architecture map: 2026-05-06*
