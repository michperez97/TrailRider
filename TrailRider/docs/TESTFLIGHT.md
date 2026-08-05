# Shipping TrailRider to TestFlight

Internal-testing-only uploads, so builds skip Beta App Review and become
installable as soon as Apple finishes processing (roughly 5–30 minutes).

The embedded `TrailRiderWatch Watch App` ships inside the iPhone archive. There
is no separate export step for it.

## Uploading

```sh
TrailRider/Scripts/upload-internal-testflight.sh
node TrailRider/Scripts/testflight-build-status.mjs   # VALID = installable
```

"Upload accepted" only means Apple took the bytes. Processing can still fail, so
always run the status check afterwards.

## One-time setup still outstanding

**The App Store Connect app record does not exist yet.** Everything else is
done. Create it once, then uploads work from the command line forever after.

The App IDs are already registered (an archive on 2026-08-05 created them via
`-allowProvisioningUpdates`), so the bundle ID now appears in the dropdown.

At <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**:

| Field | Value |
| --- | --- |
| Platforms | **iOS** only — the watch app is embedded, not a separate platform |
| Name | `TrailRider` |
| Primary Language | English (U.S.) |
| Bundle ID | `Crocobyte.TrailRider` — listed as `XC Crocobyte TrailRider`, because Xcode created it |
| SKU | `trailrider-ios` |
| User Access | Full Access |

**If the name is rejected as taken**, change only the display name and keep the
bundle ID. Nutri_app hit exactly this and ships as "Nutri: Food & Health Coach"
under the bundle ID `com.crocobyte.nutriapp`. The name stays editable until the
first public App Store submission.

Then **TestFlight → Internal Testing → +** to create a group and add yourself as
a tester. Uploads succeed and process without this, but nobody can install until
a tester is assigned.

## Credentials

One App Store Connect API key for team `M98LTD3FJJ`, shared with VitaForge,
Nutri_app, and Cairn Planner. `TrailRider/.testflight.env` is gitignored via the
`*.env` rule and defines:

| Variable | Meaning |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | Key ID from App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID, the same for every key in the team |
| `APP_STORE_CONNECT_KEY_PATH` | Absolute path to the `.p8` under `~/.appstoreconnect/private_keys/` |

The `.p8` never enters the repository and should not sit in an iCloud-synced
folder.

## Never upload from a beta Xcode

App Store Connect rejects archives built by a beta toolchain, and it rejects
them during *export* — minutes after a successful archive.

This repo is developed against **Xcode 27.0 beta** (`27A5194q`; the trailing
lowercase letter is the beta marker). The upload script therefore pins
`DEVELOPER_DIR` to stable **Xcode 26.6** (`17F113`) at
`/Volumes/X9/X9_Applications/Xcode-26.6.0.app`, and re-checks the resolved build
number so a pinned path that turns out to hold a beta still aborts.

Your everyday `xcode-select` setting is untouched — keep developing on the beta.

To use a different stable Xcode:

```sh
TRAILRIDER_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  TrailRider/Scripts/upload-internal-testflight.sh
```

Both deployment targets are 26.2, below the 26.6 SDK, so the stable toolchain
satisfies them.

## Things already handled — don't redo them

- **Export compliance.** `ITSAppUsesNonExemptEncryption = false` is set in
  `TrailRider/Info.plist` *and* `TrailRiderWatch-Watch-App-Info.plist`. The watch
  app is its own bundle and does not inherit the iPhone app's answer. Without
  these keys every build stalls waiting for a manual encryption question.
- **HealthKit purpose strings on the iOS target.** The iOS app holds the
  HealthKit entitlements even though only the watch app imports HealthKit. An
  entitlement without a matching purpose string is what triggers ITMS-90683, so
  both strings were added to `TrailRider/Info.plist`.
- **Build numbers.** `manageAppVersionAndBuildNumber` is `true` in
  `TestFlightExportOptions.plist`; App Store Connect assigns them. Never bump
  `CURRENT_PROJECT_VERSION` to match a TestFlight build. `MARKETING_VERSION`
  (currently `1.0`) is the only version you set by hand.
- **Portal App IDs.** `Crocobyte.TrailRider` and
  `Crocobyte.TrailRider.watchkitapp` exist under team `M98LTD3FJJ` with
  HealthKit, HealthKit background delivery, and Sign in with Apple enabled.
  Xcode created them, so `-allowProvisioningUpdates` keeps them current — do not
  hand-edit them.
- **`GoogleService-Info.plist`.** Bundled automatically through the project's
  file-system-synchronized groups, which is why it has no `PBXBuildFile` entry.
  It is gitignored, so it must exist locally before archiving.

## If the display name needs to differ from "TrailRider"

Set `INFOPLIST_KEY_CFBundleDisplayName` on the `TrailRider` target. The bundle ID
is unaffected.
