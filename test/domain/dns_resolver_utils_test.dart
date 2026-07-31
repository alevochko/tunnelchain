import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/dns_resolver_utils.dart';

void main() {
  test('parsePublicResolvers splits comma and whitespace', () {
    expect(parsePublicResolvers('1.1.1.1,8.8.8.8'), ['1.1.1.1', '8.8.8.8']);
    expect(parsePublicResolvers('1.1.1.1  8.8.4.4'), ['1.1.1.1', '8.8.4.4']);
    expect(parsePublicResolvers('1.1.1.1'), ['1.1.1.1']);
  });

  test('formatPublicResolvers joins entries', () {
    expect(formatPublicResolvers(['1.1.1.1', '8.8.8.8']), '1.1.1.1, 8.8.8.8');
  });

  test('primaryPublicResolver returns first entry', () {
    expect(primaryPublicResolver('1.1.1.1,8.8.8.8'), '1.1.1.1');
    expect(primaryPublicResolver(''), '1.1.1.1');
  });

  test('singBoxDomainSuffixes strips leading dot for sing-box 1.9+', () {
    expect(
      singBoxDomainSuffixes(['.corp.internal', '.internal.example']),
      ['corp.internal', 'internal.example'],
    );
    expect(singBoxDomainSuffixes(['corp.internal']), ['corp.internal']);
  });
}
