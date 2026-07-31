import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/privileged_client.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';

void main() {
  group('PrivilegedResult', () {
    test('parses map from platform channel', () {
      final result = PrivilegedResult.fromMap({
        'success': true,
        'sessionToken': 'abc',
        'steps': {'clearDns': true, 'clearProxy': false},
      });

      expect(result.success, isTrue);
      expect(result.sessionToken, 'abc');
      expect(result.steps['clearDns'], isTrue);
      expect(result.steps['clearProxy'], isFalse);
    });
  });

  group('TunnelState', () {
    test('connected states', () {
      expect(TunnelState.running.isConnected, isTrue);
      expect(TunnelState.degraded.isConnected, isTrue);
      expect(TunnelState.stopped.isConnected, isFalse);
    });
  });
}
