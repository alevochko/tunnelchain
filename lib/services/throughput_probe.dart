import 'dart:io';

import 'package:tunnel_chain/domain/models/diagnostic_models.dart';

/// FR-20: measure download throughput with failure counting.
class ThroughputProbe {
  ThroughputProbe({
    this.runCount = 3,
    this.url = 'https://speed.cloudflare.com/__down?bytes=10000000',
    this.timeoutSec = 30,
  });

  final int runCount;
  final String url;
  final int timeoutSec;

  Future<DiagnosticCheck> measure() async {
    final speeds = <double>[];
    var failed = 0;

    for (var i = 0; i < runCount; i++) {
      final mbps = await _downloadOnce();
      if (mbps == null) {
        failed++;
      } else {
        speeds.add(mbps);
      }
    }

    if (speeds.isEmpty) {
      return DiagnosticCheck(
        id: 'throughput',
        title: 'Throughput measurement failed',
        detail:
            'All $runCount runs failed (HTTP 000 or timeout). '
            'Typical sign of MTU or TCP-over-TCP issues.',
        status: DiagnosticStatus.fail,
      );
    }

    final avg = speeds.reduce((a, b) => a + b) / speeds.length;
    final best = speeds.reduce((a, b) => a > b ? a : b);

    return DiagnosticCheck(
      id: 'throughput',
      title: 'Throughput measurement',
      detail:
          'avg ${avg.toStringAsFixed(1)} Mbps · best ${best.toStringAsFixed(1)} Mbps · '
          'failed $failed / $runCount runs',
      status: failed > 0 ? DiagnosticStatus.warn : DiagnosticStatus.ok,
    );
  }

  Future<double?> _downloadOnce() async {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: timeoutSec);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final stopwatch = Stopwatch()..start();
      var bytes = 0;
      await for (final chunk in response) {
        bytes += chunk.length;
      }
      stopwatch.stop();
      if (bytes == 0 || stopwatch.elapsedMilliseconds == 0) return null;
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final mbps = (bytes * 8) / seconds / 1e6;
      return mbps;
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
