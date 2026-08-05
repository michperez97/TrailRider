# TrailRider → TestFlight

**Date:** 2026-08-05
**Goal:** Ship TrailRider builds to TestFlight so the app updates over the air
instead of being re-sideloaded over a cable.

## Decision

Port the TestFlight pipeline that VitaForge and Nutri_app already run. All three
apps live under Apple Developer team `M98LTD3FJJ` and share one App Store
Connect API key, so this is a port, not a new design.

Uploads are **internal-testing-only**: no Beta App Review queue, builds reach
testers in roughly 5–30 minutes. That is the fastest remote-update loop
TestFlight offers, and it is what "update it remotely" requires.

## Starting state

Already correct, do not change:

- `CODE_SIGN_STYLE = Automatic` and `DEVELOPMENT_TEAM = M98LTD3FJJ` on all 12
  build configurations.
- Bundle IDs `Crocobyte.TrailRider` and `Crocobyte.TrailRider.watchkitapp`.
- `SWIFT_VERSION = 5.0` — not Swift 6 language mode, so an older stable
  compiler is unlikely to reject the code.
- Eight `PBXFileSystemSynchronizedRootGroup` entries, which is why
  `GoogleService-Info.plist` is bundled without appearing in the pbxproj.
  Firebase initializes in the archive with no extra build phase.

Missing, and added by this work:

- No export options plist, no upload script, no runbook.
- No `ITSAppUsesNonExemptEncryption` key in either Info.plist.
- No HealthKit usage strings on the iOS target, which holds the HealthKit
  entitlement.

## The beta-Xcode constraint

`xcode-select -p` resolves to `/Applications/Xcode-beta.app`, version 27.0,
build `27A5194q`. The trailing lowercase letter marks a beta toolchain, and
App Store Connect rejects archives built by one. The rejection lands on the
*export* step, several minutes after a successful archive.

Stable **Xcode 26.6 (`17F113`)** is installed at
`/Volumes/X9/X9_Applications/Xcode-26.6.0.app`. The upload script pins
`DEVELOPER_DIR` to it, so day-to-day development stays on the beta while
uploads use the stable toolchain. The script also re-checks the resolved
build number and refuses to run if it still looks like a beta — pinning a
path is not proof that the path holds a stable Xcode.

`IPHONEOS_DEPLOYMENT_TARGET` and `WATCHOS_DEPLOYMENT_TARGET` are both 26.2,
below the 26.6 SDK, so the deployment targets are satisfied.

## What gets added

Under `TrailRider/`:

| Path | Purpose |
| --- | --- |
| `TestFlightExportOptions.plist` | `app-store-connect` method, `upload` destination, internal testing only, App Store Connect manages build numbers |
| `Scripts/upload-internal-testflight.sh` | Archive, export, upload; pins the stable toolchain and refuses betas |
| `Scripts/testflight-build-status.mjs` | Reports whether an uploaded build finished processing |
| `docs/TESTFLIGHT.md` | Runbook |
| `.testflight.env` | Copied from VitaForge; already covered by the `*.env` rule in `TrailRider/.gitignore` |

## Info.plist changes

**Export compliance.** Add `ITSAppUsesNonExemptEncryption = false` to
`TrailRider/Info.plist` and `TrailRiderWatch-Watch-App-Info.plist`. Without it
every build stops in TestFlight waiting for a manual encryption answer, which
defeats the point of a remote update loop. The watch app is a separate bundle
and needs its own key.

**HealthKit usage strings.** `TrailRider/TrailRider.entitlements` grants
`com.apple.developer.healthkit` and `.healthkit.background-delivery` to the iOS
app, but no source file under `TrailRider/TrailRider/` imports HealthKit — only
the watch app's `WorkoutManager.swift` does, and the watch Info.plist already
carries both usage strings.

An entitlement without a matching purpose string is what App Store validation
flags as ITMS-90683. Two ways to resolve it:

1. Add `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` to
   the iOS Info.plist.
2. Remove the HealthKit entitlements from the iOS target.

**Take option 1.** It is additive and cannot change runtime behaviour. Option 2
edits capabilities on a shipping App ID to fix a problem that may not exist,
and unused purpose strings are not themselves grounds for rejection.

## Build numbering

`manageAppVersionAndBuildNumber` is `true`, so App Store Connect assigns build
numbers. `CURRENT_PROJECT_VERSION` (currently 2) is never bumped by hand or by
the script. `MARKETING_VERSION` (currently 1.0) stays the only version set
manually. This matches VitaForge and Nutri_app.

## Credentials

`TrailRider/.testflight.env` is copied from VitaForge and defines
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and an absolute
`APP_STORE_CONNECT_KEY_PATH` pointing into `~/.appstoreconnect/private_keys/`.
The `.p8` never enters the repository.

No Apple Distribution certificate for `M98LTD3FJJ` exists on this Mac; the only
local identity is `Apple Development (4C68H4B5JW)`, a different team.
`-allowProvisioningUpdates` with API-key authentication creates or downloads the
distribution certificate and both provisioning profiles on the first archive.
The same mechanism keeps the HealthKit and Sign in with Apple capabilities on
the portal App IDs in sync, so those App IDs must not be hand-edited.

## Verification

"Upload accepted" only means Apple took the bytes. Processing runs another
5–30 minutes and can still fail. After each upload:

```sh
node TrailRider/Scripts/testflight-build-status.mjs
```

`processingState: VALID` means testers can install.

## Outcome

**Xcode 26.6 compiles the project.** The first trial build failed, but on a
genuine bug rather than an SDK gap: `TrailAheadRibbonView.swift:89` read
`navigationState.cue?.kind?.accentColor`, double-chaining through
`let kind: Kind`, which is not optional. The bug arrived with commit `8b76b8a`
and would fail on any Swift compiler. Dropping the second `?` fixed it and the
Release build then succeeded with no errors. Two `MKPlacemark` deprecation
warnings remain and do not block anything.

**The App Store Connect record does not exist.** The API key authenticates and
the team holds `com.crocobyte.vitaforge`, `com.crocobyte.nutriapp`, and
`com.crocobyte.cairn`, but nothing for TrailRider. Records cannot be created
through the API — `POST /v1/apps` does not exist — so this is web-console work,
documented step by step in `TrailRider/docs/TESTFLIGHT.md`.

That forced an ordering constraint worth recording: the "New App" form only
offers bundle IDs already registered as portal Identifiers. Nothing had ever
been built against `M98LTD3FJJ` locally, so an archive had to run *first*.
It succeeded and registered `M98LTD3FJJ.Crocobyte.TrailRider` and
`M98LTD3FJJ.Crocobyte.TrailRider.watchkitapp`, both carrying HealthKit,
HealthKit background delivery, and Sign in with Apple.

**Bundle ID stays `Crocobyte.TrailRider`.** It is inconsistent with the
`com.crocobyte.*` form the other three apps use, but a bundle ID is permanent
once the record exists, and renaming would mean re-registering the app in
Firebase for a new `GoogleService-Info.plist`, moving the watch bundle ID and
`WKCompanionAppBundleIdentifier` in lockstep, and losing local ride history on
any device carrying the current build. The inconsistency is cosmetic and
private; the cost of fixing it is not.

## Remaining risk

**Internal testers are not assigned.** Nutri_app hit this: uploads succeed and
process, but nobody can install until testers are added to a group under
TestFlight → Internal Testing. Web-console work, covered in the runbook.
