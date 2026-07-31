# Workflows

---

## Environment

| Requirement | Version |
|-------------|---------|
| Flutter | stable, SDK `^3.12` |
| Dart | 3.12+ |
| Xcode CLI | for macOS build |
| OS | macOS (development and runtime) |

```bash
flutter doctor
flutter pub get
```

---

## Running the app

```bash
flutter run -d macos
```

First connect may prompt for privileged helper registration (SMAppService).

### Release build

```bash
flutter build macos --release
open build/macos/Build/Products/Release/TunnelChain.app
```

---

## Native changes (must know)

Changes in `macos/Runner/` or `macos/Helper/`:

- Hot reload **does not work**
- Requires a full rebuild: `flutter run -d macos` or `flutter build macos`

Common files:
- `StatusBarMenuController.swift` — menu bar, connect switch
- `WindowChrome.swift` — window corner radius
- `Helper/*.swift` — root operations
- `NativeChannels.swift` — channel registration

After changing a MethodChannel — update the Dart wrapper and tests.

---

## Typical agent tasks

### 1. Fix a parser

```bash
# edit lib/domain/parsers/...
flutter test test/domain/vless_parser_test.dart
flutter analyze --fatal-infos
```

### 2. Add a generator field

```bash
# lib/core_config/sing_box/hop_builder.dart
flutter test test/core_config/
```

### 3. New UI on a screen

- Look at a neighboring screen (`routing_screen.dart`, `profiles_screen.dart`)
- Register routes in `router.dart` under `AppShell`
- `flutter run -d macos` for visual check

### 4. Import/export

```bash
flutter test test/services/connection_profile_transfer_test.dart
flutter test test/services/profile_import_service_test.dart
```

### 5. Menu bar / window

```bash
flutter run -d macos   # not hot restart
```

---

## Debugging connect

1. Logs screen — sing-box log stream
2. `ClashApiClient` — traffic API
3. Helper logs — Console.app, subsystem `com.tunnelchain`
4. Generated config — path via `ConfigStore` / paths channel

If DNS/proxy is stuck after a crash — helper watchdog or manual reset via disconnect.

---

## Git remote

```bash
git remote -v
# origin  https://github.com/alevochko/tunnelchain.git
```

Push only when the user asks.

---

## Files not for commit

- `build/`, `.dart_tool/`
- `tunnelchain-profile-*.json` — user exports
- `docs/screenshots/` source captures before normalization (if kept locally)
- Any files with real keys

---

## Roadmap priorities

When choosing what to do next without an explicit request:

1. **Phase 2** — subscription URL (after VLESS is stable)
2. **Phase 3** — AmneziaWG, Hysteria2
3. Outbound picker dialog for multi-VLESS Xray configs (UX gap)
4. Diagnostics FR-18…23

Details: [ROADMAP.md](../ROADMAP.md).

---

## Useful references

| Resource | Path |
|----------|------|
| Design tokens | `lib/app/theme/`, `design-system/MASTER.md` |
| Functional requirements | `docs/FR.md` |
| Architecture decisions | `docs/ADR.md` |
