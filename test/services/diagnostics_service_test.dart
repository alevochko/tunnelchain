import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/diagnostics_service.dart';

void main() {
  group('DiagnosticsService', () {
    test('detects enabled system proxy from networksetup output', () async {
      final service = DiagnosticsService(
        runner: (executable, args) async {
          if (executable == 'networksetup' &&
              args.first == '-listallnetworkservices') {
            return ProcessResult(0, 0, 'An asterisk (*) denotes...\nWi-Fi\n', '');
          }
          if (executable == 'networksetup' && args.contains('-getwebproxy')) {
            return ProcessResult(
              0,
              0,
              'Enabled: Yes\nServer: 127.0.0.1\nPort: 12334\n',
              '',
            );
          }
          if (executable == 'networksetup') {
            return ProcessResult(0, 0, 'Enabled: No\n', '');
          }
          if (executable == 'pgrep') {
            return ProcessResult(0, 1, '', '');
          }
          if (executable == 'scutil') {
            return ProcessResult(0, 0, 'nameserver[0] : 192.168.1.1\n', '');
          }
          if (executable == 'netstat') {
            return ProcessResult(0, 0, '', '');
          }
          if (executable == '/sbin/pfctl') {
            return ProcessResult(0, 0, 'tunnelchain\n', '');
          }
          if (executable == 'ping') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      final findings = await service.runDoctor();
      expect(
        findings.any((f) => f.id == 'system-proxy' && f.severity.name == 'error'),
        isTrue,
      );
      expect(
        findings.any((f) => f.id == 'pf-rules' && f.severity.name == 'warning'),
        isTrue,
      );
    });

    test('mtuInfo uses configured mtu values', () {
      final check = DiagnosticsService().mtuInfo(tunMtu: 1280, wgMtu: 1280);
      expect(check.title, contains('1280'));
      expect(check.status.name, 'ok');
    });
  });
}
