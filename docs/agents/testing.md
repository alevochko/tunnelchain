# Testing

---

## Running tests

```bash
flutter test                    # all tests
flutter test test/domain/       # domain layer
flutter test path/to/file_test.dart
flutter analyze --fatal-infos
```

Current suite: ~89 tests. All must pass before merge.

---

## Structure

Mirror `lib/`:

```
test/
├── domain/           # parsers, validators, models
├── core_config/      # config generator snapshots
├── services/         # import, transfer, stores (with mocks)
├── app/              # app-level unit tests
└── ui/               # pure logic (chain_visualization)
```

Naming: `*_test.dart`, `main()` + `group()` + `test()`.

---

## What must be tested

| Change | Minimum tests |
|--------|---------------|
| URI/JSON parser | valid, edge, invalid, warnings |
| Validator | happy path + each violation rule |
| `hop_builder` / generator | outbound JSON snapshot |
| Codec serialize | round-trip |
| Transfer/import | rename conflicts, secret remap |
| Pure UI logic (visualization) | unit test without widget pump |

### Not required (unless asked)

- Full-app widget/integration tests
- Golden tests
- E2E connect (requires sing-box + network)

---

## Patterns

### Parser

```dart
test('parses reality grpc link', () {
  final result = VlessParser().parse(
    grpcLink,
    id: 'vps',
    name: 'VPS gRPC',
    uuidKeychainKey: 'secret.uuid',
    publicKeyKeychainKey: 'secret.pbk',
  );

  expect(result.value.transport, 'grpc');
  expect(result.value.grpcServiceName, 'GunService');
});
```

Use fixture strings at the top of the file (`const grpcLink = '...'`).

### Generator + secrets

```dart
final secrets = MapSecretResolver({
  'secret.uuid': '550e8400-e29b-41d4-a716-446655440000',
  'secret.pbk': 'testPubKey',
});

final json = ConfigGenerator().generate(
  profiles: profiles,
  chains: chains,
  tunnel: tunnel,
  secrets: secrets,
);
```

Assert outbound/inbound/route structure — not the entire file if it is huge.

### MethodChannel mock

```dart
TestWidgetsFlutterBinding.ensureInitialized();

const channel = MethodChannel('com.tunnelchain/keychain');

setUp(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async { ... });
});

tearDown(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
});
```

See `keychain_store_test.dart`, `services_test.dart`.

### ValidationException

```dart
expect(
  () => validator.validate(chain, profiles),
  throwsA(isA<ValidationException>()),
);
```

---

## Test data

- UUIDs/keys must be obviously fake (`550e8400-...`, `testPubKey`).
- Do not copy real production endpoints from user configs.
- Sample fixtures: `lib/demo/sample_tunnel.dart`, `design_preview_data.dart` — for UI preview, not always for tests.

---

## Adding tests for a new transport

1. `test/domain/vless_parser_test.dart` — URI + JSON outbound cases
2. `test/core_config/vless_grpc_config_test.dart` or `config_generator_test.dart` — sing-box output
3. `hop_builder` unit assertions if needed

Reference: existing gRPC tests from roadmap phase 1.

---

## CI

When `.github/workflows/ci.yml` exists:

- `flutter analyze --fatal-infos`
- `dart format --set-exit-if-changed .`
- `flutter test`
- `flutter build macos` (macOS runner)

Reproduce the same commands locally.
