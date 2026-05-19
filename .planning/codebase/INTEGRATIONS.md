---
last_mapped_commit: ea07f7fb52e9ce61ff56007434d01ca377215f1b
---
# External Integrations

**Analysis Date:** 2026-05-06

## APIs & External Services

**Firebase:**
- Firebase app bootstrap is performed in `TrailRider/TrailRider/App/TrailRiderApp.swift` with `FirebaseApp.configure()`.
- Firestore is the primary cloud database. Service classes build collection references from `Firestore.firestore()`.
- Firebase Auth backs Sign in with Apple and current-user authorization checks.
- Firebase Analytics is linked in `TrailRider/TrailRider.xcodeproj/project.pbxproj`.

**Apple identity and device services:**
- Sign in with Apple is implemented through `AuthenticationServices` in `TrailRider/TrailRider/ViewModels/AuthViewModel.swift` and Firebase credential exchange in `TrailRider/TrailRider/Services/AuthService.swift`.
- HealthKit is used by the watch app in `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift` for workout sessions, heart rate, active calories, and cycling distance.
- WatchConnectivity links the iOS and watch apps through `TrailRider/TrailRider/Services/WatchConnectivityService.swift` and `TrailRider/TrailRiderWatch Watch App/WorkoutManager.swift`.
- CoreLocation drives iOS ride tracking through `TrailRider/TrailRider/Services/LocationService.swift` and watch route sampling through `WorkoutManager.swift`.

## Data Storage

**Firestore collections:**
- `users` - App user profiles and aggregate stats in `TrailRider/TrailRider/Services/UserService.swift`.
- `usernames` - Username claim documents used transactionally by `UserService.claimUsername`.
- `rides` - Saved ride documents and ride history in `TrailRider/TrailRider/Services/RideService.swift`.
- `communityTrails` - Draft, published, confirmed, and edited community trails in `TrailRider/TrailRider/Services/CommunityTrailService.swift`.
- `parks` - Seeded and user-created parks in `CommunityTrailService.swift`.
- `groupSessions` - Group ride session documents and `members` subcollection in `TrailRider/TrailRider/Services/GroupRideService.swift`.
- `friendRequests` and `friendships` - Social graph data in `TrailRider/TrailRider/Services/FriendService.swift`.

**Local storage:**
- No durable local ride queue or offline persistence wrapper is implemented in inspected code.
- `TrailRider/Scripts/write-build-metadata.sh` writes a short git commit string into app resources as `GitCommit.txt` during build.

**File export:**
- `TrailRider/TrailRider/Services/GPXExporter.swift` exports ride route data to GPX.
- `TrailRider/Exports/` exists as a repo folder for generated or manual export artifacts.

## Authentication & Identity

**Auth Provider:**
- Firebase Auth with Apple credential flow.
- `AuthViewModel.handleSignInRequest` generates and hashes the nonce.
- `AuthService.signInWithApple(idToken:nonce:)` exchanges the Apple ID token for a Firebase user.

**User onboarding:**
- `AuthViewModel.handleSignedIn(firebaseUser:)` loads or creates an `AppUser` and routes to `.onboarding` when username is missing.
- `UserService.claimUsername` uses a Firestore transaction to reserve usernames and update the user document.

## Monitoring & Observability

**Error tracking:**
- No external crash or error reporting service was detected.

**Logs:**
- Errors are usually surfaced through `errorMessage`, `saveError`, or silently retained as stale data.
- `LocationService.locationManager(_:didFailWithError:)` prints location errors to console.

## CI/CD & Deployment

**Hosting:**
- Native iOS/watchOS app distribution; no server deploy target is present in this repo.

**CI Pipeline:**
- No GitHub Actions, Fastlane, or Xcode Cloud config was detected in the inspected tree.

## Environment Configuration

**Required configuration files:**
- `TrailRider/TrailRider/GoogleService-Info.plist` for Firebase.
- `TrailRider/TrailRider/Info.plist` for location permission strings and background location mode.
- `TrailRider/TrailRider/TrailRider.entitlements` for Apple Sign in and HealthKit.
- `TrailRider/TrailRiderWatch Watch App/TrailRiderWatch Watch App.entitlements` for watch HealthKit.

**Secrets location:**
- Firebase plist files are explicitly ignored in `.gitignore` and `TrailRider/.gitignore`; treat them as sensitive configuration and do not commit raw copies.
- No `.env` files were read or required for the native app path.

## Webhooks & Callbacks

**Incoming:**
- No HTTP webhook server exists in the repo.
- Watch-to-phone messages arrive through `WCSessionDelegate` methods in `WatchConnectivityService.swift`.

**Outgoing:**
- Phone-to-watch workout control messages are sent through `WatchConnectivityService.sendMessageToWatch`.
- Watch-to-phone workout events and standalone ride payloads are sent from `WorkoutManager.swift`.

---

*Integration audit: 2026-05-06*
