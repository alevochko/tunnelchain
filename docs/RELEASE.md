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

## DMG (distribution)

One command — build app and package `dist/TunnelChain-<version>-macos-<arch>.dmg`:

```bash
bash macos/scripts/build_release.sh
```

Without Apple credentials this produces an **unsigned** DMG (recipients use right-click → Open on first launch).

With signing credentials:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export TEAM_ID="TEAMID"
export APPLE_APP_PASSWORD="app-specific-password"
bash macos/scripts/build_release.sh
```

Output:

- `dist/TunnelChain-1.0.0-macos-arm64.dmg`
- `dist/TunnelChain-1.0.0-macos-arm64.dmg.sha256`

## Sign and notarize (app only)

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export TEAM_ID="TEAMID"
export APPLE_APP_PASSWORD="app-specific-password"
bash macos/scripts/notarize.sh build/macos/Build/Products/Release/TunnelChain.app
bash macos/scripts/create_dmg.sh build/macos/Build/Products/Release/TunnelChain.app
```

## GitHub Release

1. Commit and push to `main`.
2. Create and push a tag (version must match `pubspec.yaml`):

```bash
git tag v1.0.0
git push origin v1.0.0
```

3. Workflow `.github/workflows/release.yml` builds the DMG and attaches it to the GitHub Release.

Optional repository secrets (for signed + notarized CI builds):

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_ID_APPLICATION` | codesign identity string |
| `DEVELOPER_ID_HELPER` | helper identity (defaults to app identity) |
| `APPLE_ID` | notarytool Apple ID |
| `TEAM_ID` | Apple team ID |
| `APPLE_APP_PASSWORD` | app-specific password |

Without secrets, CI still uploads an unsigned DMG artifact from the workflow run.

Manual release from your Mac:

```bash
bash macos/scripts/build_release.sh
gh release create v1.0.0 dist/*.dmg dist/*.sha256 --generate-notes
```

## Acceptance smoke test (FR §11)

On a clean Mac:

1. Import VLESS + WireGuard, build nested chain, connect.
2. Run Diagnostics → leakcheck + throughput.
3. Kill `sing-box` → kill switch banner appears.
4. Reset network settings → clean `scutil --dns`, `scutil --proxy`.
5. Connect, do not confirm → auto-rollback within safety timeout.
6. Quit with active tunnel → network restored.
   - Adhoc builds: **⌘Q may prompt for admin password** (same elevated path as Connect).
   - Use **TunnelChain → Quit** or **⌘Q**, not the red window close button (hides to menu bar).

## Debug vs release helper

| Mode | Helper |
|------|--------|
| Adhoc / unsigned (Debug or Release) | `DevPrivilegedBackend` + admin password on each Connect |
| Signed + notarized | SMAppService + XPC helper (no password per connect) |

Release builds are **not App Sandbox–restricted** so the admin-password fallback works.
For Mac App Store distribution you would re-enable sandbox and rely on the XPC helper only.

Register helper (signed builds): System Settings → General → Login Items → Allow in Background → TunnelChain.
