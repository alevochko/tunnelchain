# Release checklist

## Prerequisites

- Apple Developer ID Application certificate
- `notarytool` credentials (`APPLE_ID`, `TEAM_ID`, `APPLE_APP_PASSWORD`)
- macOS 13+ build host

## Build

```bash
flutter pub get
bash macos/scripts/fetch_singbox.sh
flutter build macos --release
```

## Sign and notarize

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export TEAM_ID="TEAMID"
export APPLE_APP_PASSWORD="app-specific-password"
bash macos/scripts/notarize.sh build/macos/Build/Products/Release/TunnelChain.app
```

## Acceptance smoke test (FR §11)

On a clean Mac:

1. Import VLESS + WireGuard, build nested chain, connect.
2. Run Diagnostics → leakcheck + throughput.
3. Kill `sing-box` → kill switch banner appears.
4. Reset network settings → clean `scutil --dns`, `scutil --proxy`.
5. Connect, do not confirm → auto-rollback within safety timeout.
6. Quit with active tunnel → network restored.

## Debug vs release helper

| Mode | Helper |
|------|--------|
| Debug (unsigned) | `DevPrivilegedBackend` + admin password |
| Release | SMAppService + XPC helper |

Register helper: System Settings → Login Items → TunnelChain.
