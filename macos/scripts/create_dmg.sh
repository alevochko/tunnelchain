#!/usr/bin/env bash
# Package TunnelChain.app into a drag-to-Applications DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="${1:-$ROOT/build/macos/Build/Products/Release/TunnelChain.app}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"

if [[ ! -d "$APP" ]]; then
  echo "App bundle not found: $APP" >&2
  echo "Run: flutter build macos --release" >&2
  exit 1
fi

VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
ARCH="$(uname -m)"
DMG_NAME="TunnelChain-${VERSION}-macos-${ARCH}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

STAGING="$(mktemp -d)"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

cp -R "$APP" "$STAGING/TunnelChain.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$OUTPUT_DIR"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "TunnelChain" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "Signing DMG with $DEVELOPER_ID_APPLICATION"
  codesign --force --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
fi

if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "Notarizing DMG..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG_PATH" || true
fi

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256"
)

echo "DMG: $DMG_PATH"
echo "SHA256: $OUTPUT_DIR/$(basename "$DMG_PATH").sha256"
