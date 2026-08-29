#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version> <sha256>" >&2
  exit 64
fi

VERSION="$1"
SHA256="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASK_PATH="$ROOT_DIR/Casks/focusguard.rb"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([._+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: $VERSION" >&2
  exit 65
fi

if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Invalid SHA-256: $SHA256" >&2
  exit 65
fi

if [[ ! -f "$CASK_PATH" ]]; then
  echo "Cask not found: $CASK_PATH" >&2
  exit 66
fi

if [[ "$(grep -c '^  version "' "$CASK_PATH")" -ne 1 ]] ||
   [[ "$(grep -c '^  sha256 "' "$CASK_PATH")" -ne 1 ]]; then
  echo "Expected exactly one version and one sha256 stanza in $CASK_PATH" >&2
  exit 65
fi

sed -i.bak \
  -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
  -e "s/^  sha256 \"[0-9a-f]*\"$/  sha256 \"$SHA256\"/" \
  "$CASK_PATH"
rm -f "$CASK_PATH.bak"

echo "Updated $CASK_PATH to FocusGuard $VERSION ($SHA256)"
