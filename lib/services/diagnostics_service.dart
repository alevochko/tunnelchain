import 'dart:io';

import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
import 'package:tunnel_chain/domain/models/diagnostic_models.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Read-only checks from FR-18…FR-22.
class DiagnosticsService {
  DiagnosticsService({ProcessRunner? runner}) : _run = runner ?? _defaultRunner;

  final ProcessRunner _run;

  static Future<ProcessResult> _defaultRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }

  DiagnosticCheck mtuInfo() {
    final tunnel = SampleTunnel.tunnelConfig;
    return DiagnosticCheck(
      id: 'mtu',
      title: 'MTU ${tunnel.tunMtu} (TUN) / ${tunnel.wgMtu} (WireGuard)',
      detail:
          'Prototype default is 1280 — larger values often break large TLS transfers.',
      status: DiagnosticStatus.ok,
    );
  }

  DiagnosticCheck leakcheckStatus({required bool tunnelConnected}) {
    if (!tunnelConnected) {
      return const DiagnosticCheck(
        id: 'leakcheck',
        title: 'Nesting verification',
        detail: 'Connect a chain first, then run leakcheck (tcpdump on physical iface).',
        status: DiagnosticStatus.idle,
        actionLabel: 'Run after connect',
      );
    }
    return const DiagnosticCheck(
      id: 'leakcheck',
      title: 'Nesting verification',
      detail:
          'Capture on physical interface: UDP to inner endpoint must be silent; traffic to outer hop must be visible.',
      status: DiagnosticStatus.idle,
      actionLabel: 'Run leakcheck',
    );
  }

  DiagnosticCheck throughputPlaceholder() {
    return const DiagnosticCheck(
      id: 'throughput',
      title: 'Throughput measurement',
      detail: 'Not implemented yet — will report avg / best / failed runs (FR-20).',
      status: DiagnosticStatus.idle,
    );
  }

  Future<DiagnosticCheck> resolveHost(String host) async {
    final result = await _run('dig', ['+short', '+time=4', host]);
    final stdout = (result.stdout as String).trim();
    if (result.exitCode == 0 && stdout.isNotEmpty) {
      final first = stdout.split('\n').first.trim();
      return DiagnosticCheck(
        id: 'dns-$host',
        title: '$host resolves',
        detail: first,
        status: DiagnosticStatus.ok,
      );
    }
    return DiagnosticCheck(
      id: 'dns-$host',
      title: '$host does not resolve',
      detail: (result.stderr as String).trim().isEmpty
          ? 'No answer from system resolver'
          : (result.stderr as String).trim(),
      status: DiagnosticStatus.fail,
    );
  }

  Future<List<DiagnosticCheck>> runDnsSuite() async {
    final hosts = ['google.com', 'internal.example'];
    final checks = <DiagnosticCheck>[];
    for (final host in hosts) {
      checks.add(await resolveHost(host));
    }
    return checks;
  }

  Future<List<DoctorFinding>> runDoctor() async {
    final findings = <DoctorFinding>[];

    final singbox = await _run('pgrep', ['-fl', 'sing-box run']);
    final singboxRunning =
        singbox.exitCode == 0 && (singbox.stdout as String).trim().isNotEmpty;
    findings.add(
      DoctorFinding(
        id: 'singbox-process',
        title: singboxRunning ? 'sing-box is running' : 'sing-box is not running',
        detail: singboxRunning
            ? (singbox.stdout as String).trim().split('\n').first
            : 'No active sing-box process found.',
        severity: DoctorSeverity.info,
      ),
    );

    final plist = File('/Library/LaunchDaemons/com.tunnelchain.app.singbox.plist');
    if (await plist.exists()) {
      findings.add(
        const DoctorFinding(
          id: 'launchd-plist',
          title: 'TunnelChain launchd plist present',
          detail: '/Library/LaunchDaemons/com.tunnelchain.app.singbox.plist',
          severity: DoctorSeverity.warning,
          fixLabel: 'Reset network settings',
        ),
      );
    }

    final proxy = await _detectSystemProxy();
    if (proxy != null) {
      findings.add(
        DoctorFinding(
          id: 'system-proxy',
          title: 'System HTTP proxy is enabled',
          detail: proxy,
          severity: DoctorSeverity.error,
          fixLabel: 'Reset network settings',
        ),
      );
    } else {
      findings.add(
        const DoctorFinding(
          id: 'system-proxy',
          title: 'System proxy is off',
          detail: 'No enabled web proxy on network services.',
          severity: DoctorSeverity.info,
        ),
      );
    }

    final dnsPinned = await _dnsPinned();
    if (dnsPinned && !singboxRunning) {
      findings.add(
        DoctorFinding(
          id: 'dns-pin',
          title: 'DNS still pinned to TUN address',
          detail:
              'Resolver ${ConfigConstants.dnsPinIp} is set but sing-box is not running.',
          severity: DoctorSeverity.error,
          fixLabel: 'Reset network settings',
        ),
      );
    } else if (dnsPinned) {
      findings.add(
        DoctorFinding(
          id: 'dns-pin',
          title: 'DNS pinned (expected while connected)',
          detail: 'System resolver: ${ConfigConstants.dnsPinIp}',
          severity: DoctorSeverity.info,
        ),
      );
    } else {
      findings.add(
        const DoctorFinding(
          id: 'dns-pin',
          title: 'DNS pin cleared',
          detail: 'No TunnelChain DNS pin detected.',
          severity: DoctorSeverity.info,
        ),
      );
    }

    final tunRoutes = await _run('netstat', ['-rn', '-f', 'inet']);
    if ((tunRoutes.stdout as String).contains('172.19.0')) {
      findings.add(
        const DoctorFinding(
          id: 'tun-routes',
          title: 'Leftover TUN routes (172.19.0.x)',
          detail: 'Stale routes may remain after an unclean shutdown.',
          severity: DoctorSeverity.warning,
          fixLabel: 'Reset network settings',
        ),
      );
    }

    final ping = await _run('ping', ['-c', '1', '-t', '3', '1.1.1.1']);
    findings.add(
      DoctorFinding(
        id: 'icmp',
        title: ping.exitCode == 0 ? 'ICMP to 1.1.1.1 works' : 'ICMP to 1.1.1.1 failed',
        detail: ping.exitCode == 0
            ? 'Basic internet reachability OK.'
            : 'No reply from 1.1.1.1 — check routes or firewall.',
        severity: ping.exitCode == 0 ? DoctorSeverity.info : DoctorSeverity.warning,
      ),
    );

    return findings;
  }

  Future<String?> _detectSystemProxy() async {
    final list = await _run('networksetup', ['-listallnetworkservices']);
    if (list.exitCode != 0) return null;

    final services = (list.stdout as String)
        .split('\n')
        .skip(1)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('*'));

    for (final service in services) {
      final web = await _run('networksetup', ['-getwebproxy', service]);
      if (web.exitCode != 0) continue;
      final text = (web.stdout as String).replaceAll('\n', ' ');
      if (text.contains('Enabled: Yes')) {
        return '$service: $text';
      }
    }
    return null;
  }

  Future<bool> _dnsPinned() async {
    final result = await _run('scutil', ['--dns']);
    if (result.exitCode != 0) return false;
    return (result.stdout as String).contains(ConfigConstants.dnsPinIp);
  }
}
