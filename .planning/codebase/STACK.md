---
last_mapped_commit: ea07f7fb52e9ce61ff56007434d01ca377215f1b
---
# Technology Stack

**Analysis Date:** 2026-05-06

## Languages

**Primary:**
- Swift - Used for the iOS app, watchOS app, app models, services, view models, SwiftUI views, and tests.

**Secondary:**
- Shell - Build metadata script at `TrailRider/Scripts/write-build-metadata.sh`.
- Property lists - App configuration, entitlements, and Firebase configuration in `TrailRider/TrailRider/Info.plist`, `TrailRider/TrailRider/TrailRider.entitlements`, and `TrailRider/TrailRider/GoogleService-Info.plist`.

## Runtime

**Environment:**
- Native Apple platforms through Xcode project `TrailRider/TrailRider.xcodeproj`.
- iOS deployment target is `26.2` for `TrailRider`, `TrailRiderTests`, and `TrailRiderUITests`.
- watchOS deployment target is `26.2` for `TrailRiderWatch Watch App` and watch test targets.

**Package Manager:**
- Swift Package Manager via the Xcode project package reference to `https://github.com/firebase/firebase-ios-sdk`.
- No `Package.swift`, CocoaPods `Podfile`, or npm package manifest was detected for the app itself.

## Frameworks

**Core:**
- SwiftUI - Primary UI framework across `TrailRider/TrailRider/Views/`, `TrailRider/TrailRider/Theme/`, and `TrailRider/TrailRiderWatch Watch App/`.
- Observation - View models and stateful services use `@Observable`, commonly with `@MainActor`.
- CoreLocation - Ride tracking, trail coordinates, park radius checks, and watch GPS sampling.
- MapKit - Trail maps, ride maps, route replay, and active ride map camera behavior.
- WatchConnectivity - Phone/watch workout and standalone ride synchronization.
- HealthKit - Watch workout sessions, heart rate, active energy, and cycling distance.
- AuthenticationServices and CryptoKit - Sign in with Apple nonce generation and Firebase auth credential exchange.

**Firebase:**
- FirebaseCore - App bootstrap in `TrailRider/TrailRider/App/TrailRiderApp.swift`.
- FirebaseAuth - Sign in and current-user checks in `TrailRider/TrailRider/Services/AuthService.swift`, `RideService.swift`, and `GroupRideService.swift`.
- FirebaseFirestore - Data storage and Codable mapping across models and service classes.
- FirebaseAnalytics - Linked package product in `TrailRider/TrailRider.xcodeproj/project.pbxproj`.

**Testing:**
- Swift Testing - Unit tests use `import Testing` and `@Test` in `TrailRider/TrailRiderTests/TrailRiderTests.swift`.
- XCTest - UI test targets use XCTest in `TrailRider/TrailRiderUITests/` and `TrailRider/TrailRiderWatch Watch AppUITests/`.

## Key Dependencies

**Critical:**
- `firebase-ios-sdk` `12.10.0` - Provides Firebase Analytics, Auth, and Firestore products.
- `GoogleService-Info.plist` - Firebase runtime config exists at `TrailRider/TrailRider/GoogleService-Info.plist`; do not print or copy its contents into docs or commits.

**Resolved transitive packages:**
- `GoogleAppMeasurement` `12.10.0`
- `GoogleUtilities` `8.1.0`
- `GTMSessionFetcher` `5.1.0`
- `AppCheck` `11.2.0`
- `gRPC` `1.69.1`
- `leveldb` `1.22.5`
- `nanopb` `2.30910.0`

## Configuration

**Build:**
- Xcode schemes: `TrailRider`, `TrailRiderWatch Watch App`, and `TrailRiderWatch Watch App (Notification)`.
- Build configurations: `Debug` and `Release`.
- Main bundle ID: `Crocobyte.TrailRider`.
- Watch bundle ID: `Crocobyte.TrailRider.watchkitapp`.
- Development team in project settings: `M98LTD3FJJ`.

**Entitlements and permissions:**
- iOS app enables Sign in with Apple, HealthKit, and HealthKit background delivery in `TrailRider/TrailRider/TrailRider.entitlements`.
- Watch app enables HealthKit and HealthKit background delivery in `TrailRider/TrailRiderWatch Watch App/TrailRiderWatch Watch App.entitlements`.
- iOS app declares location usage strings and `UIBackgroundModes = location` in `TrailRider/TrailRider/Info.plist`.

## Platform Requirements

**Development:**
- Use Xcode with SwiftUI, Swift Testing, XCTest, and Apple platform SDKs new enough for the configured iOS/watchOS 26.2 targets.
- Open and build through `TrailRider/TrailRider.xcodeproj`.

**Production:**
- Requires valid Apple signing for iOS app, watch app, HealthKit, and Sign in with Apple.
- Requires Firebase project configuration and Firestore indexes/rules outside the source currently inspected.

---

*Stack analysis: 2026-05-06*
