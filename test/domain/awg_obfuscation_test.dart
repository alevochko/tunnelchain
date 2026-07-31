import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/awg_obfuscation.dart';

void main() {
  test('trivial AWG params are not non-trivial', () {
    const obf = AwgObfuscation(jc: 0, s: [0, 0, 0, 0], h: [1, 2, 3, 4]);
    expect(obf.isNonTrivial(), isFalse);
  });

  test('active AWG obfuscation is detected', () {
    const obf = AwgObfuscation(jc: 4, s: [1, 0, 0, 0]);
    expect(obf.isNonTrivial(), isTrue);
  });
}
