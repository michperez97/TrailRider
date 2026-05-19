---
last_mapped_commit: ea07f7fb52e9ce61ff56007434d01ca377215f1b
---
# Coding Conventions

**Analysis Date:** 2026-05-06

## Swift Style

- Use SwiftUI-first composition for app screens.
- Keep feature screen files under `TrailRider/TrailRider/Views/<Feature>/`.
- Use `struct <Name>: View` for SwiftUI views.
- Use `@Observable` plus `@MainActor` for mutable UI-facing state objects.
- Use `final class <Domain>Service: Sendable` for singleton service wrappers.
- Use `static let shared` and a private initializer for app-wide platform/Firebase services.
- Use `MARK:` sections to group state, controls, helpers, and delegate conformance.

## State And Concurrency

- View models that mutate UI state should be `@MainActor`.
- Delegate callbacks from Objective-C frameworks use `nonisolated` methods and hop back to the main actor with `Task { @MainActor in ... }`.
- Timer closures should avoid direct cross-actor mutation; existing code uses `Task { @MainActor [weak self] in ... }`.
- Use async/await for Firestore service methods instead of callback-style APIs where available.
- Snapshot listener methods return `ListenerRegistration` so callers can manage lifetime.

## Service Patterns

- Firestore collection references are computed private properties:
  - `private var db: Firestore { Firestore.firestore() }`
  - `private var ridesCollection: CollectionReference { db.collection("rides") }`
- Prefer batched writes or transactions for multi-document invariants:
  - `RideService.saveRide` writes the ride and increments `users/{uid}.totalMiles` in one batch.
  - `UserService.claimUsername` reserves usernames transactionally.
  - `CommunityTrailService.confirmTrail` prevents duplicate confirmations transactionally.
- Services throw `NSError` with `NSLocalizedDescriptionKey` for user-visible domain failures.

## Model Patterns

- Firestore-backed models use `Codable`, `Identifiable`, and usually `Sendable`.
- Firestore document IDs use `@DocumentID var id: String?`.
- Firestore coordinate storage uses `GeoPoint` where documents need Firestore-native geography.
- Derived `CLLocationCoordinate2D` values are exposed as computed properties where needed for maps.

## Error Handling

- View models keep user-facing error state such as `errorMessage` or `saveError`.
- Some non-critical failures are intentionally swallowed to preserve UX:
  - `AuthViewModel.refreshCurrentUser` keeps stale data on failure.
  - `RideViewModel.saveStandaloneWatchRide` saves anyway if dedup lookup fails.
- Avoid broad silent failures on new critical flows; if persistence, auth, or import fails, expose enough error detail for the UI or logs.

## UI And Design System

- Use the shared `Color.tr*` palette from `TrailRider/TrailRider/Theme/ThemeColors.swift`.
- Use button styles from `TrailRider/TrailRider/Theme/TrailButton.swift` instead of ad hoc button styling.
- Use `tactileCard(...)` from `TactileCard.swift` for card surfaces.
- Use `ThemedTextField` for form fields to preserve prompt and color treatment.
- Dark mode is enforced at `RootView` with `.preferredColorScheme(.dark)`.

## Navigation And View Composition

- Root routing belongs in `RootView`.
- Top-level tab ownership belongs in `MainTabView`.
- Feature view navigation is local to each feature view.
- Views can create feature-local view models with `@State`, while shared auth state comes from `@Environment(AuthViewModel.self)`.

## Firestore Query Conventions

- User-specific reads should filter by `userId` or related user identifiers.
- Use ordered reads for history-style views, for example `RideService.getRides(userId:)` orders by `startTime` descending.
- Use `compactMap { try? $0.data(as: Model.self) }` for tolerant list decoding, but avoid this when data loss must be visible.
- Be aware that compound queries may require Firestore composite indexes.

## Watch Connectivity Conventions

- Phone-side watch state belongs in `WatchConnectivityService`.
- Watch workout and HealthKit state belongs in `WorkoutManager`.
- Use small dictionary payloads for WatchConnectivity messages.
- Keep phone and watch payload key names synchronized; standalone ride import depends on exact keys.

## File Hygiene

- Do not read or copy `GoogleService-Info.plist` contents into generated docs.
- Keep generated build artifacts out of source with `build/`, `DerivedData/`, and `.build/` ignored.
- When modifying Xcode project settings, inspect `TrailRider/TrailRider.xcodeproj/project.pbxproj` carefully because it is already locally modified.

---

*Convention map: 2026-05-06*
