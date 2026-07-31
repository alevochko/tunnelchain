# TunnelChain — Agent Guide

Guide for AI agents and developers: how the project is structured, where to put code, and what to verify before finishing a task.

**Status:** macOS Flutter app `0.1.0`, early development. Single platform — macOS.

---

## Quick start

1. Read [overview and domain model](docs/agents/overview.md).
2. Before making changes — [architecture and layer boundaries](docs/agents/architecture.md).
3. While writing code — [coding standards](docs/agents/coding-standards.md).
4. Before finishing — [testing](docs/agents/testing.md) and [workflows](docs/agents/workflows.md).

**Canonical project documents** (read when requirements are unclear):

| Document | When to read |
|----------|--------------|
| [docs/FR.md](docs/FR.md) | Behavior, acceptance criteria |
| [docs/AR.md](docs/AR.md) | Components, data model, packet path |
| [docs/ADR.md](docs/ADR.md) | Rationale for design decisions |
| [docs/ROADMAP.md](docs/ROADMAP.md) | In scope / out of scope |
| [README.md](README.md) | Human-oriented overview, setup |

---

## Hard rules (do not break)

### Architecture

- **Domain must not know sing-box JSON** — only models, parsers, validators, codecs.
- **Single place for config.json generation** — `lib/core_config/` (`ConfigGenerator` → `SingBoxConfigurator`).
- **UI must not contain business logic** — routing, validation, import live in domain/services/state.
- **Secrets only via Keychain** — `SecretRef` in models; on-disk JSON stores references, not values.
- **sing-box is a separate process** — do not link or embed it (GPL, [ADR-002](docs/ADR.md#adr-002)).
- **Chains ⊥ routing** — a chain describes *how* a channel is built; profile/routing describes *where* traffic goes ([ADR-012](docs/ADR.md#adr-012)).

### Security and networking

- Do not log UUIDs, keys, tokens, or Keychain contents.
- Do not write secrets to `profiles.json` or export bundles (except explicitly documented ref-based formats).
- Network changes only through the privileged helper — never directly from Dart.
- On connect, always account for auto-rollback and `ResetService` — one network restore path.

### Change scope

- **Minimal diff** — do not refactor neighboring code unless asked.
- **Do not add dependencies** without a clear need.
- **Do not commit** `.env`, profile exports, onboarding screenshots, `build/`.
- **Conventional commits:** `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

---

## Where to put new code

| Task | Location |
|------|----------|
| New model (Profile, Chain, …) | `lib/domain/models/` + export in `domain.dart` if needed |
| URI / JSON parser | `lib/domain/parsers/` → `ParseResult<T>` + warnings |
| Invariant validation | `lib/domain/validators/` → `ValidationException` |
| JSON file serialization | `lib/domain/serialization/` |
| sing-box outbound/route/dns | `lib/core_config/sing_box/` |
| Storage, XPC, import | `lib/services/` |
| Riverpod state | `lib/state/` |
| Screen / dialog / widget | `lib/ui/screens/`, `dialogs/`, `widgets/` |
| Theme, router | `lib/app/` |
| macOS native (menu bar, helper) | `macos/Runner/`, `macos/Helper/` |
| Tests | `test/` — mirror `lib/` structure |

Details: [docs/agents/architecture.md](docs/agents/architecture.md).

---

## Common scenarios

### New VLESS transport / protocol option

1. `vless_transport.dart` / `vless_parser.dart` — parsing.
2. `VlessProfile` — model fields.
3. `hop_builder.dart` — outbound JSON.
4. `config_generator_test.dart` + `vless_parser_test.dart`.
5. UI preview in `node_import_dialog.dart` / `profiles_screen.dart`.

See [ROADMAP phase 1](docs/ROADMAP.md).

### New protocol (not VLESS)

1. Model + `ProfileKind` / `ProtocolKind`.
2. Parser + codec.
3. `hop_builder` or a dedicated builder.
4. Enable chip in UI (disabled chips today — do not enable without a full pipeline).
5. End-to-end generator tests.

### Profile import / export

- Codec: `connection_profile_bundle_codec.dart`.
- Service: `connection_profile_transfer_service.dart`.
- Dialogs: `connection_profile_import_dialog.dart`, `connection_profile_transfer_actions.dart`.
- On id conflict — rename + remap secret keys (tests exist).

### UI screen

- `ConsumerWidget` / `ConsumerStatefulWidget` + Riverpod.
- Colors/spacing/typography — only `AppColors`, `AppSpacing`, `AppTypography`.
- Icons — `lucide_icons_flutter` via `NavIcon` or direct imports.
- Do not hardcode hex colors in widgets.

### Swift changes (menu bar, helper, window)

- Full rebuild: `flutter run -d macos` or `flutter build macos`.
- Hot reload does **not** apply to native code.
- Method channels: `com.tunnelchain/*` prefix — see [workflows](docs/agents/workflows.md).

---

## Pre-submit checklist

```
[ ] flutter analyze --fatal-infos
[ ] flutter test
[ ] New logic covered by tests (domain / core_config required)
[ ] Secrets not leaked to logs or JSON
[ ] UI uses design tokens
[ ] No stray files in the commit
[ ] For native changes — mention rebuild requirement
```

---

## Repository layout

```
lib/
├── app/           # theme, router
├── core_config/   # ConfigGenerator, sing-box mapping
├── domain/        # models, parsers, validators, serialization
├── services/      # stores, helper client, import
├── state/         # Riverpod providers
└── ui/            # screens, dialogs, widgets, onboarding

macos/
├── Runner/        # Flutter host, channels, status bar, window chrome
└── Helper/        # privileged SMAppService daemon

docs/
├── FR.md AR.md ADR.md ROADMAP.md
└── agents/        # this guide (details)

test/              # mirror of lib/
tool/              # screenshot and maintenance scripts
```

---

## Related files

- [docs/agents/overview.md](docs/agents/overview.md) — domain, terms, invariants
- [docs/agents/architecture.md](docs/agents/architecture.md) — layers, dependencies, data flow
- [docs/agents/coding-standards.md](docs/agents/coding-standards.md) — Dart/Flutter/Swift style
- [docs/agents/testing.md](docs/agents/testing.md) — what and how to test
- [docs/agents/workflows.md](docs/agents/workflows.md) — build, git, CI, debugging

---

## Language

All agent documentation and code identifiers are in **English**. Commit messages and UI strings (until localized) are in **English**.
