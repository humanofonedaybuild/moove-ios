#!/bin/bash
#
# archive-and-upload.sh
#
# Produces a signed App Store distribution archive of the Moove Alarm Clock
# iOS app and uploads it to App Store Connect / TestFlight using the App Store
# Connect API key (recommended over Apple ID auth — no 2FA prompt, CI-safe).
#
# Prerequisites (must be satisfied before running):
#
#   1. RevenueCat hardening complete and the working tree clean
#      (the archive must be built from the final, hardened state — see MOO-97).
#   2. A valid Apple Distribution certificate + its private key installed in
#      the login keychain on this machine (or injected via CI secrets).
#   3. An App Store provisioning profile for `com.moove.alarmclock` installed
#      (or downloaded automatically via --allowProvisioningUpdates + API key).
#   4. The App Store Connect API key (.p8) for "Moove CI" (App Manager) saved
#      to disk and its path exported as ASC_KEY_PATH, with ASC_KEY_ID and
#      ASC_ISSUER_ID set. From MOO-76:
#        Key ID:    CS8X55UJ9D
#        Issuer ID: a89b5cf3-0649-4300-8bf8-36b67d995288
#
# Configuration is read from environment variables (all required unless noted):
#
#   DEVELOPMENT_TEAM       Apple Developer Team ID (e.g. ABCD1234WXY)
#   ASC_KEY_PATH           Absolute path to the AuthKey_<KEYID>.p8 file
#   ASC_KEY_ID             App Store Connect API key ID  (CS8X55UJ9D)
#   ASC_ISSUER_ID           App Store Connect issuer ID  (a89b5cf3-...)
#   BUMP_BUILD             optional "1" to auto-bump CFBundleVersion before archiving
#   SKIP_UPLOAD            optional "1" to stop after producing the .xcarchive
#   SKIP_BETA_REVIEW       optional "1" to upload but not submit for beta review
#
# Usage:
#   DEVELOPMENT_TEAM=XXXX ASC_KEY_PATH=/path/AuthKey.p8 ASC_KEY_ID=CS8X55UJ9D \
#     ASC_ISSUER_ID=a89b5cf3-... ./scripts/archive-and-upload.sh
#
set -euo pipefail

MOOVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MOOVE_DIR"

# --- Required configuration ---------------------------------------------------
require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: required environment variable '$name' is not set" >&2
    exit 1
  fi
}

require_env DEVELOPMENT_TEAM
require_env ASC_KEY_PATH
require_env ASC_KEY_ID
require_env ASC_ISSUER_ID

if [ ! -f "$ASC_KEY_PATH" ]; then
  echo "ERROR: ASC_KEY_PATH ('$ASC_KEY_PATH') does not exist" >&2
  exit 1
fi

BUNDLE_ID="com.moove.alarmclock"
SCHEME="Moove"
PROJECT="Moove.xcodeproj"
ARCHIVE_PATH="$MOOVE_DIR/build/Moove.xcarchive"
IPA_DIR="$MOOVE_DIR/build/ipa"
IPA_PATH="$IPA_DIR/Moove.ipa"
EXPORT_OPTIONS="$MOOVE_DIR/scripts/ExportOptions.plist"

echo "=== Moove TestFlight archive + upload ==="
echo "Bundle ID:      $BUNDLE_ID"
echo "Team:           $DEVELOPMENT_TEAM"
echo "Scheme:         $SCHEME"
echo "API Key ID:     $ASC_KEY_ID"
echo "Archive output: $ARCHIVE_PATH"
echo ""

# --- 0. Sanity: working tree should be clean & revenuecat-hardened -----------
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "WARNING: working tree has uncommitted changes. The archive should be" >&2
  echo "built from a clean, revenuecat-hardened commit (MOO-97). Aborting." >&2
  echo "Commit or stash changes, then re-run." >&2
  exit 1
fi

# --- 1. Regenerate the Xcode project -----------------------------------------
echo "=== Generating Xcode project ==="
xcodegen generate
python3 scripts/patch-scheme-storekit.py

# --- 2. Optional build-number bump -------------------------------------------
if [ "${BUMP_BUILD:-0}" = "1" ]; then
  echo "=== Bumping build number ==="
  CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Moove-Info.plist)
  NEXT=$((CURRENT + 1))
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT" Resources/Moove-Info.plist
  echo "CFBundleVersion: $CURRENT -> $NEXT"
fi

# Read marketing + build versions for logging
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Moove-Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Moove-Info.plist)
echo "Version: $VERSION ($BUILD)"

# --- 3. ExportOptions.plist for App Store distribution ------------------------
echo "=== Writing ExportOptions.plist ==="
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>${DEVELOPMENT_TEAM}</string>
  <key>uploadBitcode</key>
  <false/>
  <key>uploadSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
  <key>signingStyle</key>
  <string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.moove.alarmclock</key>
    <string>Moove App Store</string>
  </dict>
</dict>
</plist>
EOF

# --- 4. Archive (Release, signed) --------------------------------------------
echo "=== Archiving (Release) ==="
rm -rf "$ARCHIVE_PATH"
mkdir -p "$MOOVE_DIR/build"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  2>&1 | xcpretty; ARCHIVE_EXIT=${PIPESTATUS[0]}; if [ $ARCHIVE_EXIT -ne 0 ]; then exit $ARCHIVE_EXIT; fi

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "ERROR: archive was not produced at $ARCHIVE_PATH" >&2
  exit 1
fi
echo "Archive OK: $ARCHIVE_PATH"

if [ "${SKIP_UPLOAD:-0}" = "1" ]; then
  echo "SKIP_UPLOAD=1 -> stopping after archive." >&2
  echo "Archive: $ARCHIVE_PATH"
  exit 0
fi

# --- 5. Export the signed IPA ------------------------------------------------
echo "=== Exporting signed IPA ==="
rm -rf "$IPA_DIR"
mkdir -p "$IPA_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$IPA_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  2>&1 | xcpretty; EXPORT_EXIT=${PIPESTATUS[0]}; if [ $EXPORT_EXIT -ne 0 ]; then exit $EXPORT_EXIT; fi

if [ ! -f "$IPA_PATH" ]; then
  echo "ERROR: IPA was not produced at $IPA_PATH" >&2
  exit 1
fi
echo "IPA OK: $IPA_PATH"

# --- 6. Validate the build with App Store Connect ----------------------------
echo "=== Validating build with App Store Connect ==="
xcrun altool --validate-app \
  -f "$IPA_PATH" \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --verbose 2>&1 || { echo "ERROR: validation failed" >&2; exit 1; }
echo "Validation OK"

# --- 7. Upload to App Store Connect / TestFlight -----------------------------
echo "=== Uploading to App Store Connect ==="
xcrun altool --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --verbose 2>&1 || { echo "ERROR: upload failed" >&2; exit 1; }
echo "Upload OK"

# --- 8. Submit for TestFlight beta review (optional) -------------------------
if [ "${SKIP_BETA_REVIEW:-0}" != "1" ]; then
  echo "=== Submitting build $VERSION ($BUILD) for TestFlight beta review ==="
  echo "Note: programmatic beta-review submission uses the App Store Connect"
  echo "API (betaReview submission). This step is intentionally a no-op here —"
  echo "submit via the App Store Connect UI or the 'TestFlight' tab once the"
  echo "build finishes processing (~15-30 min). Board approval of the first"
  echo "build is required (Internal Testing -> add testers)."
fi

echo ""
echo "=== DONE ==="
echo "Build $VERSION ($BUILD) uploaded to App Store Connect."
echo "It will appear in TestFlight once processing completes (~15-30 min)."
