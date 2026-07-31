#!/usr/bin/env bash
# Full release build: Flutter app + optional sign/notarize + DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> fetch sing-box"
bash macos/scripts/fetch_singbox.sh

echo "==> flutter build macos --release"
flutter build macos --release

APP="$ROOT/build/macos/Build/Products/Release/TunnelChain.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed: $APP missing" >&2
  exit 1
fi

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "==> sign + notarize app"
  bash macos/scripts/notarize.sh "$APP"
else
  echo "==> skipping codesign (DEVELOPER_ID_APPLICATION not set)"
fi

echo "==> create DMG"
bash macos/scripts/create_dmg.sh "$APP"

echo "==> done"
ls -lh "$ROOT/dist/"
