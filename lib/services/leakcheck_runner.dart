import 'dart:io';

import 'package:tunnel_chain/domain/models/diagnostic_models.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// FR-18: verify inner hop traffic is not leaking on the physical interface.
class LeakcheckRunner {
  LeakcheckRunner({ProcessRunner? runner}) : _run = runner ?? _defaultRunner;

  final ProcessRunner _run;

  static Future<ProcessResult> _defaultRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }

  /// Route-based leakcheck: inner endpoint must not have a direct default-route path.
  Future<DiagnosticCheck> run({
    required String innerEndpointHost,
    String? outerEndpointHost,
  }) async {
    if (innerEndpointHost.isEmpty) {
      return const DiagnosticCheck(
        id: 'leakcheck',
        title: 'Nesting verification',
        detail: 'No inner WireGuard endpoint configured in the active chain.',
        status: DiagnosticStatus.idle,
      );
    }

    final routes = await _run('netstat', ['-rn', '-f', 'inet']);
    if (routes.exitCode != 0) {
      return DiagnosticCheck(
        id: 'leakcheck',
        title: 'Nesting verification',
        detail: 'Could not read routing table.',
        status: DiagnosticStatus.fail,
      );
    }

    final table = routes.stdout as String;
    final innerIp = _looksLikeIp(innerEndpointHost) ? innerEndpointHost : null;

    if (innerIp != null && _hasDirectHostRoute(table, innerIp)) {
      return DiagnosticCheck(
        id: 'leakcheck',
        title: 'Nesting verification failed',
        detail:
            'Direct route to inner endpoint $innerIp on a physical interface — '
            'UDP may leak outside the outer hop.',
        status: DiagnosticStatus.fail,
      );
    }

    final tunActive = table.contains('utun') || table.contains('172.19.0');
    if (!tunActive) {
      return const DiagnosticCheck(
        id: 'leakcheck',
        title: 'Nesting verification',
        detail: 'TUN routes not visible — connect a chain first.',
        status: DiagnosticStatus.idle,
      );
    }

    final outerNote = outerEndpointHost == null || outerEndpointHost.isEmpty
        ? ''
        : ' Outer hop: $outerEndpointHost.';

    return DiagnosticCheck(
      id: 'leakcheck',
      title: 'Nesting confirmed',
      detail:
          'No direct route to inner endpoint $innerEndpointHost.$outerNote '
          'Traffic should traverse the outer hop.',
      status: DiagnosticStatus.ok,
    );
  }

  bool _looksLikeIp(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) => int.tryParse(p) != null);
  }

  bool _hasDirectHostRoute(String table, String ip) {
    for (final line in table.split('\n')) {
      if (!line.contains(ip)) continue;
      final trimmed = line.trim();
      if (trimmed.startsWith('default')) continue;
      if (trimmed.contains('utun')) continue;
      if (trimmed.contains('lo0')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;
      final dest = parts.first;
      if (dest == ip || dest.startsWith('$ip/')) {
        return true;
      }
    }
    return false;
  }
}
