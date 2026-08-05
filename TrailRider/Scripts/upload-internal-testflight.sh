#!/bin/zsh

# Archives TrailRider and uploads it to internal TestFlight.
#
# The embedded "TrailRiderWatch Watch App" ships inside this archive; there is
# no second export step for it.
#
# Credentials come from a gitignored .testflight.env beside the project (see
# docs/TESTFLIGHT.md). The .p8 itself never enters the repository.

set -euo pipefail

script_directory=${0:A:h}
project_directory=${script_directory:h}
export_options="$project_directory/TestFlightExportOptions.plist"
testflight_credentials="$project_directory/.testflight.env"

# --- Toolchain -------------------------------------------------------------
#
# App Store Connect rejects archives built by a beta Xcode, and it rejects them
# during export -- minutes after a successful archive. This repo is developed
# against an Xcode beta, so uploads pin a stable toolchain instead of trusting
# whatever `xcode-select` currently points at.

default_stable_xcode="/Volumes/X9/X9_Applications/Xcode-26.6.0.app/Contents/Developer"
developer_directory="${TRAILRIDER_DEVELOPER_DIR:-$default_stable_xcode}"

if [[ ! -d "$developer_directory" ]]; then
  print -u2 "Stable Xcode not found at: $developer_directory"
  print -u2 "Install it, or point TRAILRIDER_DEVELOPER_DIR at another stable Xcode's Developer directory."
  exit 1
fi

export DEVELOPER_DIR="$developer_directory"

# A pinned path is not proof of a stable toolchain -- verify what it actually
# resolves to. Apple's build numbers end in a lowercase letter while a release
# is still seeded (27A5194q), and in a digit once it ships (17F113).
xcode_build_version=$(/usr/bin/xcodebuild -version | /usr/bin/awk '/^Build version/ { print $3 }')

if [[ "$xcode_build_version" =~ '[a-z]$' ]]; then
  print -u2 "Refusing to upload: $DEVELOPER_DIR is a beta Xcode (build $xcode_build_version)."
  print -u2 "App Store Connect rejects beta-built archives during export."
  exit 1
fi

print "Building with Xcode build $xcode_build_version at $DEVELOPER_DIR"

# --- Credentials -----------------------------------------------------------

if [[ -f "$testflight_credentials" ]]; then
  source "$testflight_credentials"
fi

authentication_arguments=()
if [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" || \
      -n "${APP_STORE_CONNECT_ISSUER_ID:-}" || \
      -n "${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
  if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}" || \
        -z "${APP_STORE_CONNECT_ISSUER_ID:-}" || \
        -z "${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
    print -u2 "App Store Connect API-key authentication is incomplete."
    print -u2 "Set APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, and APP_STORE_CONNECT_KEY_PATH."
    exit 1
  fi

  if [[ "$APP_STORE_CONNECT_KEY_PATH" != /* ]]; then
    print -u2 "APP_STORE_CONNECT_KEY_PATH must be an absolute path."
    exit 1
  fi

  if [[ ! -f "$APP_STORE_CONNECT_KEY_PATH" ]]; then
    print -u2 "App Store Connect private key not found at: $APP_STORE_CONNECT_KEY_PATH"
    exit 1
  fi

  authentication_arguments=(
    -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
  print "Using App Store Connect API-key authentication."
else
  # No Apple Distribution certificate for M98LTD3FJJ exists locally, so this
  # path only works if an Apple ID for that team is signed into Xcode.
  print "No .testflight.env found; falling back to the Apple account configured in Xcode."
fi

# --- Archive and upload ----------------------------------------------------

temporary_directory=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/trailrider-testflight.XXXXXX")
archive_path="$temporary_directory/TrailRider.xcarchive"
export_path="$temporary_directory/export"

cleanup() {
  /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT

cd "$project_directory"

print "Archiving TrailRider for App Store Connect..."
# -allowProvisioningUpdates lets Xcode create the distribution certificate and
# both provisioning profiles, and keeps the HealthKit / Sign in with Apple
# capabilities on the portal App IDs in sync. Do not hand-edit those App IDs.
/usr/bin/xcodebuild \
  -project TrailRider.xcodeproj \
  -scheme TrailRider \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  "${authentication_arguments[@]}" \
  archive

print "Uploading an internal-TestFlight-only build..."
/usr/bin/xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path" \
  -allowProvisioningUpdates \
  "${authentication_arguments[@]}"

print ""
print "Upload accepted. Apple still has to process it (roughly 5-30 minutes)."
print "Check whether it became installable:"
print "  node ${script_directory}/testflight-build-status.mjs"
