import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/throughput_probe.dart';

void main() {
  test('ThroughputProbe reports failure when all downloads fail', () async {
    final probe = ThroughputProbe(
      runCount: 2,
      url: 'http://127.0.0.1:1/nope',
      timeoutSec: 1,
    );
    final check = await probe.measure();
    expect(check.status.name, 'fail');
    expect(check.detail, contains('All 2 runs failed'));
  });
}
