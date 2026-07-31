import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/diagnostic_report_exporter.dart';

void main() {
  group('DiagnosticReportExporter.redactSecrets', () {
    test('redacts sensitive JSON keys', () {
      const raw = '''
{
  "outbounds": [
    {
      "type": "vless",
      "uuid": "secret-uuid",
      "password": "p@ss"
    }
  ],
  "private_key": "abc123"
}
''';
      final out = DiagnosticReportExporter.redactSecrets(raw);
      expect(out, contains('"uuid": "<redacted>"'));
      expect(out, contains('"password": "<redacted>"'));
      expect(out, contains('"private_key": "<redacted>"'));
      expect(out, isNot(contains('secret-uuid')));
    });

    test('redacts vless uri and wireguard conf literals', () {
      const uri = 'vless://real-uuid@host:443?security=reality#name';
      const conf = '[Interface]\nPrivateKey = abc\n[Peer]\nPresharedKey = def';
      expect(
        DiagnosticReportExporter.redactSecrets(uri),
        'vless://<redacted>@host:443?security=reality#name',
      );
      expect(
        DiagnosticReportExporter.redactSecrets(conf),
        contains('PrivateKey=<redacted>'),
      );
      expect(
        DiagnosticReportExporter.redactSecrets(conf),
        contains('PresharedKey=<redacted>'),
      );
    });
  });
}
