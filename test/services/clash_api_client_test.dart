import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';

void main() {
  test('parseTrafficSample reads int and string bps', () {
    final sample = ClashApiClient.parseTrafficSample({
      'up': 1024,
      'down': '2048',
    });
    expect(sample.uploadBps, 1024);
    expect(sample.downloadBps, 2048);
  });

  test('parseTrafficSample tolerates missing fields', () {
    final sample = ClashApiClient.parseTrafficSample(null);
    expect(sample.uploadBps, 0);
    expect(sample.downloadBps, 0);
  });
}
