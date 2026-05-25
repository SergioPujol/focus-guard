#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FocusGuard"
PRODUCT_NAME="FocusGuard"
BUNDLE_ID="${BUNDLE_ID:-app.focusguard.FocusGuard}"
VERSION="${VERSION:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/.build/release-artifacts"
APP_PATH="$ARTIFACTS_DIR/$APP_NAME.app"
ZIP_PATH="$ARTIFACTS_DIR/$APP_NAME-macOS.zip"
EXECUTABLE_PATH="$ROOT_DIR/.build/release/$PRODUCT_NAME"

rm -rf "$APP_PATH" "$ZIP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$ARTIFACTS_DIR"

swift build -c release --product "$PRODUCT_NAME"
cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>FocusGuard reads browser tab titles and URLs to decide whether your current work still matches your active promise.</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>FocusGuard can inspect your work surface when you explicitly enable screenshot-based classification.</string>
</dict>
</plist>
PLIST

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_PATH"
fi

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
    echo "NOTARY_PROFILE requires SIGNING_IDENTITY because notarization only applies to Developer ID signed apps." >&2
    exit 1
  fi
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
fi

echo "$ZIP_PATH"
