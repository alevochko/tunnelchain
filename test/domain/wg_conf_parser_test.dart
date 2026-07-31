import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/parsers/wg_conf_parser.dart';

void main() {
  late String trivialConf;
  late String activeConf;

  setUp(() async {
    trivialConf = await File(
      'test/domain/fixtures/trivial_awg.conf',
    ).readAsString();
    activeConf = await File(
      'test/domain/fixtures/active_awg.conf',
    ).readAsString();
  });

  test('parses wg-quick conf and splits DNS from search domains', () {
    final result = WgConfParser().parse(
      trivialConf,
      id: 'corp',
      name: 'Corp',
      privateKeyKeychainKey: 'secret.wg.priv',
    );

    expect(result.value.dnsServers, ['10.0.0.53']);
    expect(result.value.searchDomains, contains('corp.internal'));
    expect(result.value.searchDomains, contains('internal.example'));
    expect(result.value.endpointHost, '198.51.100.20');
    expect(result.value.endpointPort, 51820);
    expect(result.value.obfuscation?.isNonTrivial(), isFalse);
  });

  test('detects active AWG obfuscation', () {
    final result = WgConfParser().parse(
      activeConf,
      id: 'corp',
      name: 'Corp',
      privateKeyKeychainKey: 'secret.wg.priv',
    );

    expect(result.value.obfuscation?.isNonTrivial(), isTrue);
    expect(result.warnings, isNotEmpty);
  });
}
