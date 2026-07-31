import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';
import 'package:tunnel_chain/services/config_store.dart';
import 'package:tunnel_chain/services/core_controller.dart';
import 'package:tunnel_chain/services/privileged_client.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';

import '../services/fake_privileged_client.dart';

class _FakeClashApi extends ClashApiClient {
  @override
  Future<bool> isReachable() async => true;

  @override
  Stream<TrafficSample> trafficStream() async* {}
}

void main() {
  test('connect enters awaitingConfirm without auto-confirm', () async {
    final client = FakePrivilegedClient();
    final controller = CoreController(
      privileged: client,
      clashApi: _FakeClashApi(),
      configStore: LocalConfigStore(),
    );

    await controller.connect(
      configJson: '{}',
      safetyTimeoutSec: 300,
      killSwitch: true,
    );

    expect(controller.state, TunnelState.awaitingConfirm);
    expect(client.calls, isNot(contains('confirm')));
  });

  test('session poller detects kill switch engaged', () async {
    final client = FakePrivilegedClient();
    final controller = CoreController(
      privileged: client,
      clashApi: _FakeClashApi(),
      configStore: LocalConfigStore(),
    );

    client.sessionStatus = const HelperSessionStatus(
      sessionActive: true,
      singboxRunning: false,
      killSwitchEngaged: true,
      killSwitchEnabled: true,
    );

    await controller.connect(
      configJson: '{}',
      safetyTimeoutSec: 0,
      killSwitch: true,
    );

    await Future<void>.delayed(const Duration(seconds: 3));
    expect(controller.state, TunnelState.killSwitchEngaged);
  });
}
