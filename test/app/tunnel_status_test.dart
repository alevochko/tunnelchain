import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/app/theme/tunnel_status.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';

void main() {
  test('tunnel status labels are unique and non-empty', () {
    for (final status in TunnelVisualStatus.values) {
      expect(status.label, isNotEmpty);
    }
    final labels = TunnelVisualStatus.values.map((s) => s.label).toSet();
    expect(labels.length, TunnelVisualStatus.values.length);
  });

  test('maps lifecycle states to visual status', () {
    expect(mapTunnelState(TunnelState.stopped), TunnelVisualStatus.stopped);
    expect(
      mapTunnelState(TunnelState.validating),
      TunnelVisualStatus.connecting,
    );
    expect(mapTunnelState(TunnelState.running), TunnelVisualStatus.running);
    expect(
      mapTunnelState(TunnelState.awaitingConfirm),
      TunnelVisualStatus.awaitingConfirm,
    );
    expect(mapTunnelState(TunnelState.resetting), TunnelVisualStatus.resetting);
  });
}
