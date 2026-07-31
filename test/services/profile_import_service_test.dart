import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/keychain_store.dart';
import 'package:tunnel_chain/services/profile_import_service.dart';
import 'package:tunnel_chain/services/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tunnelchain/keychain');
  final secrets = <String, String>{};
  String? vaultJson;
  late List<MethodCall> calls;

  setUp(() {
    secrets.clear();
    vaultJson = null;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'write':
          final args = call.arguments as Map;
          secrets[args['key'] as String] = args['value'] as String;
          return true;
        case 'readVault':
          return vaultJson;
        case 'writeVault':
          vaultJson = (call.arguments as Map)['json'] as String;
          return true;
        case 'read':
          final key = (call.arguments as Map)['key'] as String;
          return secrets[key];
        case 'delete':
          secrets.remove((call.arguments as Map)['key'] as String);
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const vlessLink =
      'vless://550e8400-e29b-41d4-a716-446655440000@vps.example.com:443'
      '?type=tcp&security=reality&pbk=testPubKey&fp=chrome'
      '&sni=cdn.example.com&sid=abc&flow=xtls-rprx-vision';

  const wgConf = '''
[Interface]
PrivateKey = EOneqFYge/y/jHeEMNRjptzUUR5YeQrHVSt81CpZ0Eg=
Address = 10.0.0.2/32
DNS = 10.0.0.53, internal.example

[Peer]
PublicKey = DOqrZQ6+bYiq3Dr8qJ2yFYMDS1Y2zevVBqIifmz8niU=
PresharedKey = 8DbDwZN+tJoLkjF77gGbBBO8xxLrqDfPWwvuWLLCaE8=
Endpoint = 198.51.100.20:51820
AllowedIPs = 10.0.0.0/8
PersistentKeepalive = 10
''';

  test('import vless stores secrets and profile', () async {
    final store = LocalProfileStore();
    final service = ProfileImportService(
      store: store,
      keychain: KeychainStore(),
    );

    final result = await service.importVless(uri: vlessLink, name: 'VPS');
    expect(result.profile.name, 'VPS');
    expect(calls.any((c) => c.method == 'writeVault'), isTrue);

    final profiles = await store.load();
    expect(profiles.length, 1);
  });

  test('import wireguard conf stores secrets and profile', () async {
    final store = LocalProfileStore();
    final service = ProfileImportService(
      store: store,
      keychain: KeychainStore(),
    );

    final result = await service.importWireGuardConf(
      content: wgConf,
      name: 'Inner',
      fileName: 'inner.conf',
    );
    expect(result.profile.name, 'Inner');
    expect(calls.any((c) => c.method == 'writeVault'), isTrue);

    final profiles = await store.load();
    expect(profiles.length, 1);
  });
}
