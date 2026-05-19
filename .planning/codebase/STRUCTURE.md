---
last_mapped_commit: ea07f7fb52e9ce61ff56007434d01ca377215f1b
---
# Codebase Structure

**Analysis Date:** 2026-05-06

## Repository Layout

```text
.
├── TrailRider/
│   ├── TrailRider.xcodeproj/
│   ├── TrailRider/
│   │   ├── App/
│   │   ├── Models/
│   │   ├── Services/
│   │   ├── Theme/
│   │   ├── ViewModels/
│   │   └── Views/
│   ├── TrailRiderTests/
│   ├── TrailRiderUITests/
│   ├── TrailRiderWatch Watch App/
│   ├── TrailRiderWatch Watch AppTests/
│   ├── TrailRiderWatch Watch AppUITests/
│   ├── Scripts/
│   └── docs/
├── TrailGPX/
├── .codex/
└── .planning/
```

## Main App Directories

**Application bootstrap:**
- `TrailRider/TrailRider/App/TrailRiderApp.swift` - App delegate, Firebase configure, watch activation, app scene.
- `TrailRider/TrailRider/App/RootView.swift` - Auth-state root routing.
- `TrailRider/TrailRider/App/MainTabView.swift` - Tab navigation.
- `TrailRider/TrailRider/App/BuildInfo.swift` - Build metadata reading.

**Models:**
- `TrailRider/TrailRider/Models/Ride.swift` - Saved ride schema and route points.
- `TrailRider/TrailRider/Models/User.swift` - `AppUser` profile model.
- `TrailRider/TrailRider/Models/Trail.swift`, `CommunityTrail.swift`, `Park.swift`, `TrailEdit.swift`, `TrailMapData.swift` - Trail and park domain.
- `TrailRider/TrailRider/Models/GroupSession.swift`, `FriendRequest.swift`, `Bike.swift` - Social and group ride domain.
- `TrailRider/TrailRider/Models/StandaloneWatchRidePayload.swift` - Watch payload conversion into `Ride`.

**Services:**
- `TrailRider/TrailRider/Services/AuthService.swift` - Firebase Auth + Apple credential exchange.
- `TrailRider/TrailRider/Services/UserService.swift` - User document and username transactions.
- `TrailRider/TrailRider/Services/RideService.swift` - Ride persistence and total-mile batch updates.
- `TrailRider/TrailRider/Services/LocationService.swift` - CoreLocation tracking.
- `TrailRider/TrailRider/Services/WatchConnectivityService.swift` - Phone-side watch messages and standalone payloads.
- `TrailRider/TrailRider/Services/CommunityTrailService.swift` - Community trail, park, verification, edit workflow.
- `TrailRider/TrailRider/Services/GroupRideService.swift` - Group sessions and member listeners.
- `TrailRider/TrailRider/Services/FriendService.swift` - Friend requests and friendships.
- `TrailRider/TrailRider/Services/GPXExporter.swift` - GPX generation.

**View models:**
- `TrailRider/TrailRider/ViewModels/AuthViewModel.swift`
- `TrailRider/TrailRider/ViewModels/RideViewModel.swift`
- `TrailRider/TrailRider/ViewModels/RideHistoryViewModel.swift`
- `TrailRider/TrailRider/ViewModels/RideReplayViewModel.swift`
- `TrailRider/TrailRider/ViewModels/TrailCreatorViewModel.swift`
- `TrailRider/TrailRider/ViewModels/CommunityTrailsViewModel.swift`
- `TrailRider/TrailRider/ViewModels/GroupRideViewModel.swift`
- `TrailRider/TrailRider/ViewModels/FriendsViewModel.swift`

**Views by feature:**
- Auth: `TrailRider/TrailRider/Views/Auth/`
- Home: `TrailRider/TrailRider/Views/Home/`
- Ride recording and replay: `TrailRider/TrailRider/Views/Ride/`
- Trail discovery and trail creation: `TrailRider/TrailRider/Views/Trails/`
- Social: `TrailRider/TrailRider/Views/Social/`
- Profile and ride history: `TrailRider/TrailRider/Views/Profile/`

**Theme:**
- Shared palette and shape style extensions: `TrailRider/TrailRider/Theme/ThemeColors.swift`.
- Buttons: `TrailRider/TrailRider/Theme/TrailButton.swift`.
- Cards and stats: `TactileCard.swift`, `ThemeStatCard.swift`, `RideOverlayBadge.swift`.
- Text fields, icons, shimmer, and animations: `ThemeTextField.swift`, `TrailRiderIcon.swift`, `ShimmerView.swift`, `AnimationModifiers.swift`.

## Watch App Directories

**watchOS app:**
- `TrailRider/TrailRiderWatch Watch App/TrailRiderWatchApp.swift`
- `TrailRider/TrailRiderWatch Watch App/StartView.swift`
- `TrailRider/TrailRiderWatch Watch App/WorkoutView.swift`
- `TrailRider/TrailRiderWatch Watch App/SummaryView.swift`
- `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift`

**Watch tests:**
- `TrailRider/TrailRiderWatch Watch AppTests/TrailRiderWatch_Watch_AppTests.swift`
- `TrailRider/TrailRiderWatch Watch AppUITests/`

## Tests

- App unit tests: `TrailRider/TrailRiderTests/TrailRiderTests.swift`.
- App UI tests: `TrailRider/TrailRiderUITests/`.
- Watch unit/UI tests: `TrailRider/TrailRiderWatch Watch AppTests/` and `TrailRider/TrailRiderWatch Watch AppUITests/`.

## Generated Or Tooling Directories

- `.codex/` - Local GSD Codex install. Do not edit generated GSD files unless intentionally customizing GSD.
- `.planning/` - GSD planning artifacts.
- `.claude/worktrees/` - Existing Claude worktree artifacts.
- `.playwright-mcp/` - Local browser testing artifacts.
- `TrailRider/build/` - Xcode build output.

## Naming Conventions

- Swift files use one primary type per file where practical.
- Feature views group by user workflow under `Views/<Feature>/`.
- View models are named `<Feature>ViewModel`.
- Firebase and platform wrappers are named `<Domain>Service`.
- Shared UI style types use the `Trail`, `Theme`, `Tactile`, or `tr` prefix.

## Placement Rules

- Put Firestore CRUD and listener code in `Services`, not directly in views.
- Put user-facing view state in `ViewModels`, not service singletons.
- Put pure Codable schemas in `Models`; keep computed UI formatting in view models or views.
- Put design-system colors/buttons/cards in `Theme` before adding feature-local duplicates.
- Put watch-specific HealthKit logic in `WorkoutManager.swift`; mirror phone communication in `WatchConnectivityService.swift`.

---

*Structure map: 2026-05-06*
