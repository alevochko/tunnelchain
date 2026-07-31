import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/diagnostic_models.dart';
import 'package:tunnel_chain/services/leakcheck_runner.dart';

void main() {
  group('LeakcheckRunner', () {
    test('reports fail when direct route to inner endpoint exists', () async {
      final runner = LeakcheckRunner(
        runner: (executable, args) async {
          if (executable == 'netstat') {
            return ProcessResult(
              0,
              0,
              '10.0.0.5/32      link#15            UCS                   en0\n'
              'default            192.168.1.1        UGScg                 en0\n',
              '',
            );
          }
          throw UnimplementedError();
        },
      );

      final check = await runner.run(innerEndpointHost: '10.0.0.5');
      expect(check.status, DiagnosticStatus.fail);
      expect(check.title, contains('failed'));
    });

    test('reports ok when no direct route and tun active', () async {
      final runner = LeakcheckRunner(
        runner: (executable, args) async {
          if (executable == 'netstat') {
            return ProcessResult(
              0,
              0,
              '172.19.0.1         link#20            UCS                   utun4\n',
              '',
            );
          }
          throw UnimplementedError();
        },
      );

      final check = await runner.run(
        innerEndpointHost: '10.0.0.5',
        outerEndpointHost: '203.0.113.10',
      );
      expect(check.status, DiagnosticStatus.ok);
      expect(check.title, contains('confirmed'));
    });
  });
}
