#!/usr/bin/env bash
# Downloads a pinned sing-box release into macos/Runner/Resources for bundling.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="${ROOT}/Runner/Resources"
VERSION="${SING_BOX_VERSION:-1.11.7}"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64) ASSET="sing-box-${VERSION}-darwin-arm64.tar.gz" ;;
  x86_64) ASSET="sing-box-${VERSION}-darwin-amd64.tar.gz" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

mkdir -p "$RESOURCES"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/${ASSET}"
echo "Fetching ${URL}"
curl -fsSL "$URL" -o "${TMP}/${ASSET}"
tar -xzf "${TMP}/${ASSET}" -C "$TMP"
BIN="$(find "$TMP" -name sing-box -type f | head -1)"
install -m 755 "$BIN" "${RESOURCES}/sing-box"
echo "Installed ${RESOURCES}/sing-box ($( "${RESOURCES}/sing-box" version 2>/dev/null || echo unknown ))"
