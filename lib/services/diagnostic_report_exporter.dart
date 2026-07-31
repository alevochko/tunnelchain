import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tunnel_chain/domain/models/diagnostic_models.dart';
import 'package:tunnel_chain/services/config_store.dart';
import 'package:tunnel_chain/services/diagnostics_service.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';
import 'package:tunnel_chain/state/tunnel_session.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Snapshot passed from UI when exporting a diagnostic bundle.
class DiagnosticExportContext {
  const DiagnosticExportContext({
    required this.session,
    this.diagnostics,
    this.liveLogLines = const [],
    this.appVersion = '1.0.0+1',
  });

  final TunnelUiState session;
  final DiagnosticsReport? diagnostics;
  final List<String> liveLogLines;
  final String appVersion;
}

class DiagnosticReportExporter {
  DiagnosticReportExporter({
    ConfigStore? configStore,
    DiagnosticsService? diagnostics,
    ProcessRunner? runner,
  })  : _configStore = configStore ?? MacConfigStore(),
        _diagnostics = diagnostics ?? DiagnosticsService(),
        _run = runner ?? _defaultRunner;

  final ConfigStore _configStore;
  final DiagnosticsService _diagnostics;
  final ProcessRunner _run;

  static Future<ProcessResult> _defaultRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }

  static final _secretKeyPattern = RegExp(
    r'(private[_-]?key|pre[_-]?shared[_-]?key|password|uuid|secret|psk|token|authorization)',
    caseSensitive: false,
  );

  static const _logPaths = [
    '/tmp/tunnelchain-dev.log',
    '/var/log/tunnelchain-singbox.log',
    '/var/log/tunnelchain-singbox.err.log',
  ];

  Future<String> buildReport(DiagnosticExportContext ctx) async {
    final buffer = StringBuffer();
    final now = DateTime.now().toUtc();

    _section(buffer, 'TunnelChain diagnostic report');
    buffer.writeln('Generated (UTC): ${now.toIso8601String()}');
    buffer.writeln('App version: ${ctx.appVersion}');
    buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');

    await _writeConnectionState(buffer, ctx);
    await _writeDoctor(buffer, ctx);
    await _writeConfigFiles(buffer);
    await _writeSystem(buffer);
    await _writeLogFiles(buffer);
    _writeLiveLogs(buffer, ctx.liveLogLines);

    return buffer.toString();
  }

  Future<String?> saveReport(DiagnosticExportContext ctx) async {
    final report = await buildReport(ctx);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save diagnostic report',
      fileName: 'tunnelchain-diagnostic-$stamp.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (path == null || path.isEmpty) return null;

    final file = File(path.endsWith('.txt') ? path : '$path.txt');
    await file.writeAsString(report);
    return file.path;
  }

  Future<void> _writeConnectionState(
    StringBuffer buffer,
    DiagnosticExportContext ctx,
  ) async {
    _section(buffer, 'Connection state');
    final s = ctx.session;
    buffer.writeln('tunnelState: ${s.tunnelState.name}');
    buffer.writeln('helperStatus: ${s.helperStatus} (${s.helperStatusLabel})');
    buffer.writeln('helperAvailable: ${s.helperAvailable}');
    buffer.writeln('externalIp: ${s.externalIp ?? '(unknown)'}');
    buffer.writeln('activeChain: ${s.activeChainName ?? '(none)'}');
    buffer.writeln('layers: ${s.layerLabels.join(' → ')}');
    if (s.connectedSince != null) {
      buffer.writeln('connectedSince: ${s.connectedSince!.toUtc().toIso8601String()}');
    }
    buffer.writeln('uploadBps: ${s.uploadBps}');
    buffer.writeln('downloadBps: ${s.downloadBps}');
    buffer.writeln('totalUploadBytes: ${s.totalUploadBytes}');
    buffer.writeln('totalDownloadBytes: ${s.totalDownloadBytes}');
    if (s.errorMessage != null) {
      buffer.writeln('lastError: ${s.errorMessage}');
    }
    if (s.resetSteps.isNotEmpty) {
      buffer.writeln('resetSteps:');
      for (final entry in s.resetSteps.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }

    final connected =
        s.tunnelState.isConnected ||
        s.tunnelState == TunnelState.awaitingConfirm;
    buffer.writeln();
    buffer.writeln('Doctor checks (on-demand):');
    buffer.writeln('  mtu: ${_diagnostics.mtuInfo().detail}');
    buffer.writeln(
      '  leakcheck: ${connected ? "run Diagnostics screen while connected" : "connect first"}',
    );
  }

  Future<void> _writeDoctor(
    StringBuffer buffer,
    DiagnosticExportContext ctx,
  ) async {
    _section(buffer, 'Doctor findings');
    final report = ctx.diagnostics;
    if (report == null) {
      buffer.writeln('(not run in this session — running quick doctor now)');
      final findings = await _diagnostics.runDoctor();
      for (final f in findings) {
        buffer.writeln('[${f.severity.name}] ${f.title}');
        buffer.writeln('  ${f.detail}');
      }
      return;
    }

    buffer.writeln('ranAt: ${report.ranAt?.toUtc().toIso8601String() ?? '(unknown)'}');
    buffer.writeln('issueCount: ${report.issueCount}');
    buffer.writeln();
    for (final check in report.checks) {
      buffer.writeln('[${check.status.name}] ${check.title}');
      buffer.writeln('  ${check.detail}');
    }
    buffer.writeln();
    for (final finding in report.findings) {
      buffer.writeln('[${finding.severity.name}] ${finding.title}');
      buffer.writeln('  ${finding.detail}');
      if (finding.fixLabel != null) {
        buffer.writeln('  fix: ${finding.fixLabel}');
      }
    }
  }

  Future<void> _writeConfigFiles(StringBuffer buffer) async {
    _section(buffer, 'Config files (secrets redacted)');
    final dir = await _configStore.configDirectory();
    buffer.writeln('configDirectory: $dir');
    buffer.writeln();

    for (final name in ['tunnel.json', 'profiles.json', 'config.json']) {
      final path = p.join(dir, name);
      buffer.writeln('--- $name ---');
      buffer.writeln(await _readRedactedFile(path));
      buffer.writeln();
    }
  }

  Future<void> _writeSystem(StringBuffer buffer) async {
    _section(buffer, 'System');

    for (final cmd in [
      (['scutil', '--dns'], 'scutil --dns'),
      (['netstat', '-rn', '-f', 'inet'], 'netstat -rn -f inet'),
      (['ifconfig'], 'ifconfig'),
      (['networksetup', '-listallnetworkservices'], 'networksetup -listallnetworkservices'),
      (['pgrep', '-fl', 'sing-box'], 'pgrep -fl sing-box'),
    ]) {
      buffer.writeln('--- ${cmd.$2} ---');
      buffer.writeln(await _runCommand(cmd.$1));
      buffer.writeln();
    }
  }

  Future<void> _writeLogFiles(StringBuffer buffer) async {
    _section(buffer, 'Log files (tail)');
    for (final path in _logPaths) {
      buffer.writeln('--- $path ---');
      buffer.writeln(await _tailFile(path));
      buffer.writeln();
    }
  }

  void _writeLiveLogs(StringBuffer buffer, List<String> lines) {
    _section(buffer, 'Live core log buffer (Clash API)');
    if (lines.isEmpty) {
      buffer.writeln('(empty — connect and open Logs to capture stream)');
      return;
    }
    for (final line in lines) {
      buffer.writeln(line);
    }
  }

  static void _section(StringBuffer buffer, String title) {
    buffer.writeln();
    buffer.writeln('=== $title ===');
    buffer.writeln();
  }

  Future<String> _readRedactedFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return '(not found)';
      final text = await file.readAsString();
      if (text.trim().isEmpty) return '(empty)';
      return redactSecrets(text);
    } catch (e) {
      return '(read failed: $e)';
    }
  }

  Future<String> _tailFile(String path, {int maxLines = 250}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return '(not found)';
      final lines = await file.readAsLines();
      if (lines.isEmpty) return '(empty)';
      final tail = lines.length > maxLines
          ? lines.sublist(lines.length - maxLines)
          : lines;
      return tail.join('\n');
    } catch (e) {
      return '(read failed: $e)';
    }
  }

  Future<String> _runCommand(List<String> args) async {
    try {
      final result = await _run(args.first, args.sublist(1));
      final out = '${result.stdout}'.trim();
      final err = '${result.stderr}'.trim();
      if (result.exitCode != 0 && out.isEmpty) {
        return err.isEmpty ? '(exit ${result.exitCode})' : err;
      }
      if (err.isNotEmpty) {
        return '$out\n(stderr)\n$err';
      }
      return out.isEmpty ? '(no output)' : out;
    } catch (e) {
      return '(command failed: $e)';
    }
  }

  /// Redacts sensitive JSON fields and wireguard/vless literals.
  static String redactSecrets(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final redacted = _redactValue(decoded);
        return const JsonEncoder.withIndent('  ').convert(redacted);
      } catch (_) {
        // fall through to regex redaction
      }
    }
    return _redactPlainText(trimmed);
  }

  static Object? _redactValue(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key: _secretKeyPattern.hasMatch(entry.key.toString())
              ? '<redacted>'
              : _redactValue(entry.value),
      };
    }
    if (value is List) {
      return value.map(_redactValue).toList();
    }
    if (value is String) {
      return _redactPlainText(value);
    }
    return value;
  }

  static String _redactPlainText(String text) {
    var out = text;
    out = out.replaceAllMapped(
      RegExp(r'vless://[^@\s]+@'),
      (m) => 'vless://<redacted>@',
    );
    out = out.replaceAllMapped(
      RegExp(r'(PrivateKey|PresharedKey)\s*=\s*\S+', caseSensitive: false),
      (m) => '${m[1]}=<redacted>',
    );
    return out;
  }
}

final diagnosticReportExporterProvider = Provider<DiagnosticReportExporter>(
  (ref) => DiagnosticReportExporter(),
);
