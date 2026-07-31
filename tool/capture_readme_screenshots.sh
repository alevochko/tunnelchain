#!/usr/bin/env bash
# Capture TunnelChain window screenshots for README (macOS only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/macos/Build/Products/Debug/TunnelChain.app"
OUT="$ROOT/docs/screenshots"
CONFIG_DIR="$HOME/Library/Application Support/TunnelChain"

if [[ ! -d "$APP" ]]; then
  echo "Build the app first: flutter build macos --debug" >&2
  exit 1
fi

mkdir -p "$OUT"

window_id() {
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "TunnelChain"
    if (count of windows) is 0 then error "TunnelChain window not found"
    return id of front window
  end tell
end tell
APPLESCRIPT
}

capture() {
  local file="$1"
  local wid
  wid="$(window_id)"
  screencapture -x -o -l"$wid" "$file"
  echo "Saved $file"
}

# Fresh onboarding tour on first capture.
rm -f "$CONFIG_DIR/onboarding.json"

open "$APP"
sleep 4

osascript -e 'tell application "TunnelChain" to activate' || true
sleep 1

capture "$OUT/01-nodes.png"

# Advance onboarding with Right arrow (modal has keyboard focus).
for step in 2 3 4; do
  osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "TunnelChain"
    set frontmost to true
    key code 124 -- right arrow
  end tell
end tell
APPLESCRIPT
  sleep 0.8
  capture "$OUT/0${step}-$(
    case $step in 2) echo chains;; 3) echo profiles;; 4) echo connect;; esac
  ).png"
done

# Close onboarding and open Status (already on status after skip - press Escape to close modal)
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "TunnelChain"
    key code 53 -- escape / skip
  end tell
end tell
APPLESCRIPT
sleep 0.8
capture "$OUT/05-status.png"

osascript -e 'tell application "TunnelChain" to quit' || true
