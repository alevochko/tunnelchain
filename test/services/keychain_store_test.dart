import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/keychain_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.tunnelchain/keychain');
  late List<MethodCall> calls;
  String? vaultJson;

  setUp(() {
    calls = [];
    vaultJson = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'readVault':
          return vaultJson;
        case 'writeVault':
          vaultJson = (call.arguments as Map)['json'] as String;
          return true;
        case 'read':
          return null;
        case 'delete':
          return true;
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('mergeSecrets writes single vault record', () async {
    final store = KeychainStore();
    await store.mergeSecrets({'profile.a.uuid': 'uuid-a'});
    expect(calls.any((c) => c.method == 'writeVault'), isTrue);
    expect(vaultJson, contains('profile.a.uuid'));
  });

  test('getSecrets reads vault once', () async {
    vaultJson = '{"profile.a.uuid":"uuid-a","profile.b.priv":"priv-b"}';
    final store = KeychainStore();
    final secrets = await store.getSecrets([
      'profile.a.uuid',
      'profile.b.priv',
    ]);
    expect(secrets.length, 2);
    expect(calls.where((c) => c.method == 'readVault').length, 1);
    expect(calls.where((c) => c.method == 'read').length, 0);
  });
}
