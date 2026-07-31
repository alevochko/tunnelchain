import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/services/connect_safety_policy.dart';

bool shouldReconnectOnProfileChange({
  required String? previousProfileId,
  required String? nextProfileId,
  required String? previousKey,
  required String? nextKey,
}) {
  if (nextProfileId == null) return false;
  if (previousProfileId != null && previousProfileId != nextProfileId) {
    return true;
  }
  return previousProfileId != null &&
      previousProfileId == nextProfileId &&
      previousKey != null &&
      nextKey != null &&
      previousKey != nextKey;
}

void main() {
  test('effectiveSafetyTimeoutSec keeps configured value in tests (debug)', () {
    expect(effectiveSafetyTimeoutSec(300), 300);
    expect(effectiveSafetyTimeoutSec(0), 0);
  });

  test('profile switch triggers reconnect', () {
    expect(
      shouldReconnectOnProfileChange(
        previousProfileId: 'a',
        nextProfileId: 'b',
        previousKey: 'k1',
        nextKey: 'k2',
      ),
      isTrue,
    );
  });

  test('same profile routing edit triggers reconnect', () {
    expect(
      shouldReconnectOnProfileChange(
        previousProfileId: 'a',
        nextProfileId: 'a',
        previousKey: 'k1',
        nextKey: 'k2',
      ),
      isTrue,
    );
  });

  test('unchanged profile does not reconnect', () {
    expect(
      shouldReconnectOnProfileChange(
        previousProfileId: 'a',
        nextProfileId: 'a',
        previousKey: 'k1',
        nextKey: 'k1',
      ),
      isFalse,
    );
  });
}
