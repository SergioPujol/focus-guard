#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [FocusGuard-macOS.zip]" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${1:-$ROOT_DIR/.build/release-artifacts/FocusGuard-macOS.zip}"
CASK_PATH="$ROOT_DIR/Casks/focusguard.rb"

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Release archive not found: $ARCHIVE_PATH" >&2
  exit 66
fi

if [[ ! -f "$CASK_PATH" ]]; then
  echo "Cask not found: $CASK_PATH" >&2
  exit 66
fi

ARCHIVE_DIR="$(cd "$(dirname "$ARCHIVE_PATH")" && pwd)"
ARCHIVE_PATH="$ARCHIVE_DIR/$(basename "$ARCHIVE_PATH")"
ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/focusguard-homebrew-test.XXXXXX")"
TEST_TAP_ROOT="$TEST_ROOT/tap"
AUDIT_CASK="$TEST_TAP_ROOT/Casks/focusguard.rb"
TEST_CASK="$TEST_TAP_ROOT/Casks/focusguard-local-test.rb"
APP_DIR="$TEST_ROOT/Applications"
TEST_TOKEN="focusguard-local-test"
TEST_VERSION="0.1.0"
TAP_NAME="focusguard-test/local-$$"
QUALIFIED_CASK="$TAP_NAME/$TEST_TOKEN"
QUALIFIED_AUDIT_CASK="$TAP_NAME/focusguard"
TEST_ARCHIVE="$TEST_ROOT/FocusGuard-macOS-$TEST_VERSION.zip"

export HOMEBREW_NO_AUTO_UPDATE=1
export XDG_CONFIG_HOME="$TEST_ROOT/config"

cleanup() {
  brew uninstall --cask --force "$QUALIFIED_CASK" >/dev/null 2>&1 || true
  brew untap --force "$TAP_NAME" >/dev/null 2>&1 || true
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$APP_DIR" "$(dirname "$TEST_CASK")"
cp "$ARCHIVE_PATH" "$TEST_ARCHIVE"
cp "$CASK_PATH" "$AUDIT_CASK"

awk \
  -v archive_url="file://$TEST_ARCHIVE" \
  -v archive_sha256="$ARCHIVE_SHA256" '
    /^cask "focusguard" do$/ {
      print "cask \"focusguard-local-test\" do"
      next
    }
    /^  version "/ {
      print "  version \"0.1.0\""
      next
    }
    /^  sha256 "/ {
      print "  sha256 \"" archive_sha256 "\""
      next
    }
    /^  url "/ {
      print "  url \"" archive_url "\""
      next
    }
    { print }
  ' "$CASK_PATH" > "$TEST_CASK"

git -C "$TEST_TAP_ROOT" init --quiet
git -C "$TEST_TAP_ROOT" config user.name "FocusGuard Cask Test"
git -C "$TEST_TAP_ROOT" config user.email "focusguard-cask-test@localhost"
git -C "$TEST_TAP_ROOT" add Casks/focusguard.rb Casks/focusguard-local-test.rb
git -C "$TEST_TAP_ROOT" commit --quiet -m "Add local FocusGuard test cask"

brew tap "$TAP_NAME" "$TEST_TAP_ROOT"
brew install --cask --appdir="$APP_DIR" "$QUALIFIED_CASK"
brew trust --cask "$QUALIFIED_AUDIT_CASK"
brew audit --cask --strict "$QUALIFIED_AUDIT_CASK"

test -x "$APP_DIR/FocusGuard.app/Contents/MacOS/FocusGuard"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_DIR/FocusGuard.app/Contents/Info.plist")" = \
  "app.focusguard.FocusGuard"

echo "Homebrew installed FocusGuard.app successfully in $APP_DIR"
