import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';

void main() {
  group('RoutingPolicy.deepCopy', () {
    test('copies overrides without sharing mutable lists', () {
      final original = RoutingPolicy(
        defaultTarget: const RouteTarget.chain('chain-1'),
        overrides: [
          RoutingRule(
            order: 0,
            matcher: const RuleMatcher(
              type: MatcherType.domainSuffix,
              values: ['.example.com'],
            ),
            target: const RouteTarget.chain('chain-2'),
          ),
        ],
      );

      final copy = original.deepCopy();

      expect(copy.defaultTarget.chainId, 'chain-1');
      expect(copy.overrides, hasLength(1));
      expect(copy.overrides.first.matcher.values, ['.example.com']);

      copy.overrides.first.matcher.values.add('.other.com');
      expect(original.overrides.first.matcher.values, ['.example.com']);
    });
  });
}
