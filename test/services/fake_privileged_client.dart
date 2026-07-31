import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/privileged_client.dart';

class FakePrivilegedClient implements PrivilegedClient {
  HelperInfo info = const HelperInfo(
    status: 'notRegistered',
    xpcReachable: false,
  );
  final List<String> calls = [];

  @override
  Future<PrivilegedResult> applyConfig({
    required String configPath,
    required int safetyTimeoutSec,
    List<String> dnsServers = const [],
    List<String> searchDomains = const [],
  }) async {
    calls.add('applyConfig');
    return const PrivilegedResult(success: true, sessionToken: 'test-token');
  }

  @override
  Future<void> confirm(String sessionToken) async {
    calls.add('confirm');
  }

  @override
  Future<HelperInfo> getHelperInfo() async => info;

  @override
  Future<void> openHelperSettings() async {
    calls.add('openHelperSettings');
  }

  @override
  Future<String> registerHelper() async {
    calls.add('registerHelper');
    info = const HelperInfo(status: 'enabled', xpcReachable: true);
    return 'enabled';
  }

  @override
  Future<PrivilegedResult> resetAll() async {
    calls.add('resetAll');
    return const PrivilegedResult(
      success: true,
      steps: {'clearDns': true, 'stopSingBox': true},
    );
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}

void main() {
  test('FakePrivilegedClient records reset', () async {
    final client = FakePrivilegedClient();
    final result = await client.resetAll();
    expect(result.success, isTrue);
    expect(client.calls, contains('resetAll'));
  });
}
