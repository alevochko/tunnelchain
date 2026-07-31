import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';

void main() {
  const wgChain = Chain(
    id: 'chain-wg',
    name: 'Work WG',
    hopProfileIds: ['wg-1'],
  );
  const vlessChain = Chain(
    id: 'chain-vless',
    name: 'VLESS',
    hopProfileIds: ['vless-1'],
  );
  const nestedChain = Chain(
    id: 'chain-nested',
    name: 'Work WG over Personal VLESS',
    hopProfileIds: ['vless-1', 'wg-1'],
  );

  ConnectBundle bundleFor(RoutingPolicy routing) {
    return ConnectBundle(
      profiles: const {},
      chains: const [vlessChain, wgChain, nestedChain],
      tunnel: TunnelConfig(
        routing: routing,
        dns: const DnsPolicy(),
      ),
    );
  }

  test('full-tunnel profile shows default chain name', () {
    final bundle = bundleFor(
      const RoutingPolicy(
        defaultTarget: RouteTarget.chain('chain-wg'),
      ),
    );
    expect(bundle.activeChainLabel(), 'Work WG');
    expect(bundle.defaultRouteLabel(), 'Work WG');
  });

  test('split profile shows profile name as active chain', () {
    final bundle = bundleFor(
      RoutingPolicy(
        defaultTarget: const RouteTarget.direct(),
        overrides: [
          RoutingRule(
            order: 0,
            matcher: const RuleMatcher(
              type: MatcherType.domainSuffix,
              values: ['corp.example'],
            ),
            target: const RouteTarget.chain('chain-wg'),
          ),
        ],
      ),
    );
    expect(
      bundle.activeChainLabel(activeProfileName: 'Work WIFI'),
      'Work WIFI',
    );
    expect(bundle.defaultRouteLabel(), 'Direct');
  });

  test('primaryDisplayChain uses first override when default is direct', () {
    final plan = TunnelPlan(
      chains: const [wgChain, vlessChain, nestedChain],
      profiles: [
        ConnectionProfile(
          id: 'p1',
          name: 'Work WIFI',
          routing: RoutingPolicy(
            defaultTarget: const RouteTarget.direct(),
            overrides: [
              RoutingRule(
                order: 0,
                matcher: const RuleMatcher(
                  type: MatcherType.domainSuffix,
                  values: ['corp.example'],
                ),
                target: const RouteTarget.chain('chain-wg'),
              ),
            ],
          ),
        ),
      ],
      activeProfileId: 'p1',
    );

    expect(plan.primaryDisplayChain()?.name, 'Work WG');
    expect(plan.defaultChain(), isNull);
  });
}
