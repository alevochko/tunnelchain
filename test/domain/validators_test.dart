import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/validators/chain_validator.dart';
import 'package:tunnel_chain/domain/validators/routing_validator.dart';
import 'package:tunnel_chain/domain/validators/validation_exception.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final vless1 = VlessProfile(
    id: 'vless1',
    name: 'VPS',
    createdAt: now,
    host: '1.1.1.1',
    port: 443,
    uuidRef: const SecretRef('u1'),
    security: 'reality',
    sni: 'example.com',
  );
  final vless2 = VlessProfile(
    id: 'vless2',
    name: 'VPS2',
    createdAt: now,
    host: '2.2.2.2',
    port: 443,
    uuidRef: const SecretRef('u2'),
    security: 'reality',
    sni: 'example.com',
  );
  final profiles = <String, Profile>{'vless1': vless1, 'vless2': vless2};

  test('rejects duplicate protocol in chain', () {
    final chain = Chain(
      id: 'bad',
      name: 'Bad',
      hopProfileIds: ['vless1', 'vless2'],
    );
    expect(
      () => ChainValidator().validate(chain, profiles),
      throwsA(isA<ValidationException>()),
    );
  });

  test('routing validator rejects unknown chain', () {
    final policy = RoutingPolicy(
      defaultTarget: const RouteTarget.chain('missing'),
    );
    expect(
      () => RoutingValidator().validate(policy, {'vps'}),
      throwsA(isA<ValidationException>()),
    );
  });

  test('routing validator rejects duplicate order', () {
    final policy = RoutingPolicy(
      defaultTarget: const RouteTarget.direct(),
      overrides: [
        RoutingRule(
          order: 0,
          matcher: const RuleMatcher(
            type: MatcherType.ipCidr,
            values: ['10.0.0.0/8'],
          ),
          target: const RouteTarget.chain('vps'),
        ),
        RoutingRule(
          order: 0,
          matcher: const RuleMatcher(
            type: MatcherType.domainSuffix,
            values: ['corp'],
          ),
          target: const RouteTarget.chain('vps'),
        ),
      ],
    );
    expect(
      () => RoutingValidator().validate(policy, {'vps'}),
      throwsA(isA<ValidationException>()),
    );
  });
}
