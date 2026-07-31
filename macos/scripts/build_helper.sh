#!/bin/sh
set -eu

HELPER_SRC="${SRCROOT}/Helper"
HELPER_BIN="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/MacOS/TunnelChainHelper"
LAUNCHD_DIR="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Library/LaunchDaemons"
PLIST_DST="${LAUNCHD_DIR}/com.tunnelchain.app.helper.plist"
SIGN_ID="${EXPANDED_CODE_SIGN_IDENTITY:--}"

mkdir -p "$(dirname "$HELPER_BIN")" "$LAUNCHD_DIR"

swiftc -O \
  "${HELPER_SRC}/HelperConstants.swift" \
  "${HELPER_SRC}/NetworkOps.swift" \
  "${HELPER_SRC}/LaunchdManager.swift" \
  "${HELPER_SRC}/Watchdog.swift" \
  "${HELPER_SRC}/ResetService.swift" \
  "${HELPER_SRC}/HelperProtocol.swift" \
  "${HELPER_SRC}/HelperService.swift" \
  "${HELPER_SRC}/main.swift" \
  -o "$HELPER_BIN" \
  -framework Foundation

chmod 755 "$HELPER_BIN"
cp "${HELPER_SRC}/com.tunnelchain.app.helper.plist" "$PLIST_DST"

codesign --force --sign "$SIGN_ID" --options runtime \
  --entitlements "${HELPER_SRC}/Helper.entitlements" \
  "$HELPER_BIN" 2>/dev/null || codesign --force --sign - --options runtime \
  --entitlements "${HELPER_SRC}/Helper.entitlements" \
  "$HELPER_BIN"

echo "Built and signed helper at ${HELPER_BIN}"
echo "Installed launchd plist at ${PLIST_DST}"
