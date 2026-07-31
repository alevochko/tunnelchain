#!/usr/bin/env bash
# Release signing + notarization (requires Apple Developer ID credentials).
set -euo pipefail

APP="${1:-build/macos/Build/Products/Release/TunnelChain.app}"
IDENTITY="${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION}"
HELPER_IDENTITY="${DEVELOPER_ID_HELPER:-$IDENTITY}"

codesign --force --options runtime --sign "$IDENTITY" \
  --entitlements macos/Runner/Release.entitlements \
  "$APP/Contents/MacOS/TunnelChainHelper"

codesign --force --options runtime --sign "$IDENTITY" \
  --entitlements macos/Runner/Release.entitlements \
  "$APP"

ditto -c -k --keepParent "$APP" TunnelChain.zip
xcrun notarytool submit TunnelChain.zip \
  --apple-id "${APPLE_ID:?}" \
  --team-id "${TEAM_ID:?}" \
  --password "${APPLE_APP_PASSWORD:?}" \
  --wait
xcrun stapler staple "$APP"
echo "Notarized: $APP"
