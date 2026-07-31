# Architecture and layer boundaries

Full diagram: [AR.md](../AR.md). This document covers practical rules for agents.

---

## Layers and dependencies

```
UI (widgets)
  ↓ watch/read
State (Riverpod Notifiers)
  ↓ calls
Services (stores, clients, import)
  ↓ uses
Domain (models, parsers, validators)
  ↑
Core_config (ConfigGenerator) — depends only on domain + SecretResolver
```

**Forbidden dependencies:**

| From | Must not import |
|------|-----------------|
| `domain/` | `flutter`, `services`, `core_config`, `ui`, `state` |
| `core_config/` | `ui`, `state`, `services` (except `SecretResolver` interface) |
| `ui/` | direct file access, XPC, config generation |

---

## Domain layer (`lib/domain/`)

**Responsibility:** pure business logic and data models.

```
models/          — immutable data classes (Profile, Chain, RoutingPolicy, …)
parsers/         — vless_parser, wg_conf_parser, vless_outbound_parser
validators/      — chain_validator, routing_validator
serialization/   — JSON codecs for persistence and transfer
profile_secrets.dart — keychain key utilities
```

### Patterns

- Models: `const` constructors where possible, `copyWith` for updates.
- Parsers return `ParseResult<T>` with `warnings` and `secrets`.
- Validation errors: `ValidationException` with a clear message.
- Protocol enums: `ProtocolKind`, `ProfileKind`, `MatcherType`.

### Adding a field to VlessProfile

1. Field in `vless_profile.dart`
2. URI parser + outbound JSON parser
3. Codec serialize/deserialize
4. `hop_builder.dart`
5. UI preview (optional)
6. Parser and generator tests

---

## Core Config layer (`lib/core_config/`)

**The only** mapping from domain → sing-box JSON.

```
config_generator.dart      — facade
sing_box/
  sing_box_configurator.dart — orchestration
  hop_builder.dart           — outbound per hop
  route_configurator.dart    — rules, default outbound
  dns_configurator.dart      — DNS policy
  tun_configurator.dart      — TUN inbound
  chain_assembler.dart       — nested dial chain
  sing_box_tags.dart         — tag naming
config_invariants.dart       — post-build checks
secret_resolver.dart         — secret abstraction
```

### Rules

- Generate tags via `SingBoxTags` — do not hardcode strings in multiple places.
- New outbound type → changes in `hop_builder.dart` + snapshot test in `config_generator_test.dart`.
- Do not duplicate routing logic from `routing_dns_compiler` — compiler prepares domain view, generator produces sing-box.

---

## Services layer (`lib/services/`)

IO, platform, orchestration — no UI.

| Service | Role |
|---------|------|
| `profile_store` / `tunnel_plan_store` | JSON persistence |
| `keychain_store` | MethodChannel → Keychain |
| `mac_privileged_client` | DNS, routes, core lifecycle |
| `core_controller` | start/stop sing-box |
| `clash_api_client` | REST + WebSocket |
| `profile_import_service` | import pipeline |
| `connection_profile_transfer_service` | export/import bundles |
| `tunnel_connect_builder` | assemble connect context |
| `diagnostics_service` | checks FR-18…23 |

Services must **not** import `ui/`. Dependency on `state/` is acceptable only where the project already does so — prefer injection via Riverpod providers.

---

## State layer (`lib/state/`)

Riverpod 2.x pattern: `Notifier` + immutable state class + `copyWith`.

Examples:
- `profile_catalog.dart` — node list
- `tunnel_catalog.dart` — chains + connection profiles
- `tunnel_session.dart` — connect/disconnect lifecycle
- `connect_bundle.dart` — snapshot for generation

### Rules

- Async load in `build()` via `Future.microtask` or `AsyncNotifier` — follow the existing file style.
- Errors → `errorMessage` in state, not silent failure.
- Declare providers next to the Notifier in the same file.

---

## UI layer (`lib/ui/`)

```
screens/     — full-page views
dialogs/     — modal editors
widgets/     — reusable components
onboarding/  — first-run tour
chain_visualization.dart — hop / packet layer diagrams
```

### Rules

- Use `ConsumerWidget` for Riverpod access.
- Delegate business actions to notifiers (`ref.read(xxxProvider.notifier).method()`).
- Dialogs return results via `Navigator.pop` / callback — do not mutate global state directly.
- Design system: `lib/app/theme/` is the only source of visual tokens.

---

## macOS native

### Runner (`macos/Runner/`)

- Flutter host, `AppDelegate`, `MainFlutterWindow`
- Method channels: `NativeChannels.swift` registers handlers
- Status bar: `StatusBarMenuController.swift`
- Window: `WindowChrome.swift`

### Helper (`macos/Helper/`)

- Root daemon: DNS, proxy, pf, routes, launchd sing-box
- `ResetService` — single restore entry point
- `Watchdog` — timed rollback
- Built by `macos/scripts/build_helper.sh` during Xcode build

### Channels (Dart ↔ Swift)

| Channel | Dart | Purpose |
|---------|------|---------|
| `com.tunnelchain/keychain` | `KeychainStore` | vault read/write |
| `com.tunnelchain/privileged` | `MacPrivilegedClient` | helper commands |
| `com.tunnelchain/paths` | `MacConfigStore` | config paths |
| `com.tunnelchain/status_bar` | `NativeStatusBar` | menu bar UI |
| `com.tunnelchain/window_chrome` | `WindowChromeService` | corner radius |
| `com.tunnelchain/drag_drop` | `NativeDragDrop` | file drop |

When adding a channel: Swift handler + Dart wrapper + mock in tests if needed.

---

## Data flow: VLESS import

```
node_import_dialog
  → ProfileCatalogNotifier.importVless
  → ProfileImportService
  → VlessParser / VlessOutboundParser
  → KeychainStore (secrets)
  → ProfileStore.save
```

## Data flow: connect

```
status_screen / status_bar
  → TunnelSessionNotifier.connect
  → TunnelConnectBuilder
  → ConfigGenerator.toJson
  → ConfigStore.write
  → CoreController.start
  → MacPrivilegedClient (helper)
```

---

## GPL boundary

sing-box runs as a **separate binary** via the helper. Dart/Flutter code:
- writes JSON config;
- talks over REST/WS (Clash API);
- does **not** import or link GPL code.
