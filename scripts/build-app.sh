#!/bin/sh
# Build "Pullse.app" from the Swift package. Notifications only work from a real
# bundle with a bundle id, so the bare SwiftPM binary is not enough.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product Pullse
BIN="$(swift build -c release --show-bin-path)/Pullse"

APP="build/Pullse.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pullse"
cp Support/Info.plist "$APP/Contents/Info.plist"

# The bundle id is personal (macOS keys notification permission and login items by it),
# so it isn't committed: $BUNDLE_ID, else "bundleIdentifier" in the settings file, else
# a placeholder.
SETTINGS="${PULLSE_SETTINGS:-$HOME/.config/pullse/settings.json}"
BUNDLE_ID="${BUNDLE_ID:-}"
if [ -z "$BUNDLE_ID" ] && [ -f "$SETTINGS" ]; then
    BUNDLE_ID="$(plutil -extract bundleIdentifier raw -o - "$SETTINGS" 2>/dev/null || true)"
fi
if [ -z "$BUNDLE_ID" ]; then
    BUNDLE_ID="com.example.pullse"
    echo "note: no bundleIdentifier in $SETTINGS, using $BUNDLE_ID" >&2
fi
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Contents/Info.plist"

# Ad-hoc signature: enough for notifications and launch-at-login on this Mac.
codesign --force --sign - --timestamp=none "$APP"

echo "Built $APP ($BUNDLE_ID)"
