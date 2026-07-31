import 'dart:convert';

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
        case 'loadSecrets':
          final keys = (call.arguments as Map)['keys'] as List;
          final vault = vaultJson == null
              ? <String, String>{}
              : Map<String, String>.from(
                  jsonDecode(vaultJson!) as Map,
                ).map((key, value) => MapEntry('$key', '$value'));
          final secrets = <String, String>{};
          for (final key in keys) {
            final value = vault['$key'];
            if (value != null && value.isNotEmpty) {
              secrets['$key'] = value;
            }
          }
          return {'secrets': secrets, 'vaultJson': vaultJson ?? '{}'};
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

  test('getSecrets uses loadSecrets once', () async {
    vaultJson = '{"profile.a.uuid":"uuid-a","profile.b.priv":"priv-b"}';
    final store = KeychainStore();
    final secrets = await store.getSecrets([
      'profile.a.uuid',
      'profile.b.priv',
    ]);
    expect(secrets.length, 2);
    expect(calls.where((c) => c.method == 'loadSecrets').length, 1);
    expect(calls.where((c) => c.method == 'readVault').length, 0);
    expect(calls.where((c) => c.method == 'read').length, 0);
  });

  test('getSecrets uses memory cache on second call', () async {
    vaultJson = '{"profile.a.uuid":"uuid-a"}';
    final store = KeychainStore();
    await store.getSecrets(['profile.a.uuid']);
    calls.clear();
    final secrets = await store.getSecrets(['profile.a.uuid']);
    expect(secrets['profile.a.uuid'], 'uuid-a');
    expect(calls, isEmpty);
  });
}
