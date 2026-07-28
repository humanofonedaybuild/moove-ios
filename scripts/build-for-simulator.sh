#!/bin/bash
set -e

MOOVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MOOVE_DIR"

echo "=== Generating Xcode project ==="
xcodegen generate
python3 scripts/patch-scheme-storekit.py

echo "=== Building Moove for simulator ==="
xcodebuild -project Moove.xcodeproj -scheme Moove -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1

# Find the built app. Exclude Index.noindex paths (used by the IDE index, not a
# real build output) so we always pick the populated .app bundle that contains
# Frameworks/ and Metadata.appintents.
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Moove.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*" -maxdepth 6 2>/dev/null | head -1)

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "ERROR: Could not find built Moove.app" >&2
  exit 1
fi

# Resolve a single booted iPhone simulator UDID. `simctl install booted` is
# ambiguous when multiple devices (e.g. Apple Watch + iPhone) are booted at
# once, so filter to iPhone-class devices only.
SIM_UDID=$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable") and d.get("state") == "Booted" and "iPhone" in d.get("name", ""):
            print(d["udid"]); break
    else:
        continue
    break
')

if [ -z "$SIM_UDID" ]; then
  echo "No booted iPhone simulator found; booting iPhone 17 Pro" >&2
  SIM_UDID=$(xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable") and d.get("name") == "iPhone 17 Pro":
            print(d["udid"]); break
    else:
        continue
    break
')
  xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
fi
echo "Using simulator UDID: $SIM_UDID"

echo "=== Signing for simulator ==="

# Remove Metadata.appintents from MooveKit (embedded framework)
rm -rf "$APP/Frameworks/MooveKit.framework/Metadata.appintents" 2>/dev/null

# Sign MooveKit.framework with ad-hoc
/usr/bin/codesign --force --sign - --identifier=com.moove.alarmclock.kit --timestamp=none "$APP/Frameworks/MooveKit.framework" 2>&1

# Remove Metadata.appintents and old signature from main app
rm -rf "$APP/Metadata.appintents" "$APP/_CodeSignature" 2>/dev/null

# Sign Moove.app with ad-hoc and explicit bundle identifier
/usr/bin/codesign --force --sign - --identifier=com.moove.alarmclock --timestamp=none "$APP" 2>&1

echo ""
echo "=== Verification ==="
codesign -dvvv "$APP" 2>&1 | grep -E "Format=|Identifier=|Info\.plist"
echo ""

echo "=== Installing & launching ==="
xcrun simctl install "$SIM_UDID" "$APP" 2>&1
xcrun simctl launch "$SIM_UDID" com.moove.alarmclock 2>&1

echo ""
echo "DONE! Moove is running on the simulator."
