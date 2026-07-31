# Coding standards

---

## Dart / Flutter

### Analyzer and linter

Config: `analysis_options.yaml`

- `strict-casts`, `strict-inference`, `strict-raw-types` — enabled.
- `always_declare_return_types`, `prefer_single_quotes`, `prefer_const_constructors`.
- `avoid_print` — use debug logging only if the file already follows that pattern.

Before submitting:

```bash
flutter analyze --fatal-infos
dart format .
```

### Imports

- Package imports: `package:tunnel_chain/...`
- Order: dart → package → relative (linter `directives_ordering`).
- Barrel `domain/domain.dart` — for external consumers of domain models; inside domain prefer direct imports.

### Naming

| What | Style | Example |
|------|-------|---------|
| Files | `snake_case.dart` | `vless_parser.dart` |
| Classes | `PascalCase` | `VlessProfile` |
| Variables, methods | `lowerCamelCase` | `hopProfileIds` |
| Constants | `lowerCamelCase` or `k` prefix | `tcpLink` in tests |
| Providers | `xxxProvider` | `profileCatalogProvider` |
| Private | `_leadingUnderscore` | `_load()` |

### Models

```dart
class ExampleState {
  const ExampleState({this.items = const [], this.loading = false});

  final List<Item> items;
  final bool loading;

  ExampleState copyWith({List<Item>? items, bool? loading}) {
    return ExampleState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
    );
  }
}
```

- Immutable by default.
- `copyWith` with `clearError` flags where nullable fields need resetting (see `ProfileCatalogState`).

### Parsers

```dart
class ParseResult<T> {
  const ParseResult({
    required this.value,
    this.warnings = const [],
    this.secrets = const {},
  });
  // ...
}
```

- Do not throw on recoverable issues — add `warnings`.
- Throw `FormatException` / `ValidationException` only when the result is impossible.
- Extract secrets into the `secrets` map for Keychain — do not store plain text in model fields.

### Async

- Use `async`/`await` in services and notifiers.
- Check `mounted` in `StatefulWidget` after await.
- Surface errors in notifiers via `errorMessage` in state.

### UI

- Text: `AppTypography.*` — not raw `TextStyle`.
- Spacing: `AppSpacing.*` — no magic numbers (exception: 1–2px fine-tuning).
- Colors: `AppColors.*` — not `Color(0xFF...)`.
- Icons: `lucide_icons_flutter`.
- Buttons/segments: existing widgets (`DesignSegmentedControl`, patterns from neighboring screens).

### Comments

- Code should be mostly self-explanatory.
- Comments for non-obvious business logic, FR/ADR references, edge cases.
- Do not leave commented-out dead code.

### Dependencies

`pubspec.yaml` stays minimal. Before adding a package:
1. Can stdlib or existing code solve it?
2. Is it needed for one small thing only?

---

## Swift (macOS)

### Style

- Follow existing files in `macos/Runner` and `macos/Helper`.
- Method channel handlers stay thin; logic lives in dedicated types (`StatusBarMenuController`, `WindowChrome`).

### Signing and build

- Debug: ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`).
- Helper is signed in `build_helper.sh` with fallback to `-`.

### Runner / Helper changes

After any Swift change — **full rebuild** of the macOS target. Tell the user when relevant.

---

## Git

### Commits

Conventional commits, in English:

```
feat: add grpc transport to VLESS hop builder
fix: parse Xray outbounds with protocol field
docs: add agent guidelines
test: cover profile transfer rename conflicts
refactor: extract route packet path builder
chore: update CI workflow
```

- One logical change per commit when possible.
- Do not commit: `build/`, `.dart_tool/`, profile exports, onboarding screenshots.

### PR descriptions

- Summary: what and why.
- Test plan: commands and manual steps.
- Link to FR / roadmap phase when relevant.

---

## Anti-patterns (avoid)

| ❌ | ✅ |
|----|-----|
| sing-box JSON in `domain/` | `core_config/sing_box/` |
| Secret in `profiles.json` | `SecretRef` + Keychain |
| Routing logic in a widget | `routing_validator`, compiler, generator |
| New color inline in a screen | `AppColors` |
| Duplicated tag strings | `SingBoxTags` |
| Large drive-by refactor | Minimal diff for the task |
| `print()` in production path | proper error state |
| Platform channel from UI directly | service wrapper |
