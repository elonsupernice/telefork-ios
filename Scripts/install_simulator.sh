#!/bin/bash
set -euo pipefail

# Simulator only. Overlay installation preserves the app container and Keychain.
simulator_id="${1:?Usage: bash Scripts/install_simulator.sh <simulator UDID>}"
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
rtk proxy xcrun simctl list -j devices available | rtk proxy jq -e --arg id "$simulator_id" \
    '[.devices[][] | select(.udid == $id)] | length == 1' >/dev/null

derived_data="$project_dir/.codex-work/DerivedData-install"
evidence_dir="$project_dir/.codex-work/simulator-install"
rtk proxy mkdir -p "$evidence_dir"
build_args=(-project TaleFork.xcodeproj -configuration Debug
    -destination "platform=iOS Simulator,id=$simulator_id"
    -derivedDataPath "$derived_data"
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)

rtk proxy xcrun simctl bootstatus "$simulator_id" -b
# Exercise actual SecItem calls using UUID-scoped fixtures, never login secrets.
rtk proxy xcodebuild "${build_args[@]}" -scheme TaleFork-RoutingChecks \
    -parallel-testing-enabled NO \
    -only-testing:TaleForkTests/SimulatorIdentityKeychainTests \
    -only-testing:TaleForkTests/CatalogStoreTests test \
    >"$evidence_dir/keychain-test.log" 2>&1

# Rebuild without test injection; never use CODE_SIGNING_ALLOWED=NO for installs.
rtk proxy xcodebuild "${build_args[@]}" -scheme TaleFork build \
    >"$evidence_dir/build.log" 2>&1
app_bundle="$derived_data/Build/Products/Debug-iphonesimulator/TaleFork.app"
platform="$(rtk proxy /usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$app_bundle/Info.plist")"
[[ "$platform" == "iPhoneSimulator" ]]
rtk proxy codesign --verify --strict "$app_bundle"
rtk proxy codesign -dv "$app_bundle" 2>"$evidence_dir/signature.txt"
rtk proxy rg -q '^Signature=adhoc$' "$evidence_dir/signature.txt"

rtk proxy xcrun simctl install "$simulator_id" "$app_bundle"
rtk proxy xcrun simctl launch --terminate-running-process "$simulator_id" com.talefork.storypaths
printf 'Simulator install complete. Logs: %s\n' "$evidence_dir"
