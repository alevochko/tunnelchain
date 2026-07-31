import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/ui/chain_visualization.dart';

void main() {
  final createdAt = DateTime(2026, 1, 1);

  final vless = VlessProfile(
    id: 'vless-1',
    name: 'LTE node',
    createdAt: createdAt,
    host: 'nl11.example.com',
    port: 443,
    uuidRef: const SecretRef('secret.vless'),
    security: 'reality',
    sni: 'nl11.example.com',
    publicKeyRef: const SecretRef('secret.pbk'),
    shortId: 'abcd',
    fingerprint: 'chrome',
    flow: 'xtls-rprx-vision',
  );

  final wg = WireGuardProfile(
    id: 'wg-1',
    name: 'Corp WG',
    createdAt: createdAt,
    addresses: ['10.0.0.2/32'],
    privateKeyRef: const SecretRef('secret.wg'),
    peerPublicKey: 'peer-key',
    endpointHost: 'corp.example',
    endpointPort: 51820,
    allowedIps: ['10.0.0.0/8'],
  );

  const vlessChain = Chain(
    id: 'chain-vless',
    name: 'Personal VLESS',
    hopProfileIds: ['vless-1'],
  );

  const nestedChain = Chain(
    id: 'chain-nested',
    name: 'Corp via VLESS',
    hopProfileIds: ['vless-1', 'wg-1'],
  );

  final profiles = {'vless-1': vless, 'wg-1': wg};
  final chains = {
    'chain-vless': vlessChain,
    'chain-nested': nestedChain,
  };

  test('routingPaths includes default and all override rules', () {
    const viz = ChainVisualization();
    final paths = viz.routingPaths(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain('chain-vless'),
        overrides: [
          RoutingRule(
            order: 0,
            matcher: const RuleMatcher(
              type: MatcherType.ipCidr,
              values: ['192.168.1.0/24'],
            ),
            target: const RouteTarget.direct(),
          ),
          RoutingRule(
            order: 1,
            matcher: const RuleMatcher(
              type: MatcherType.domainSuffix,
              values: ['corp.example'],
            ),
            target: const RouteTarget.chain('chain-nested'),
          ),
        ],
      ),
      chainsById: chains,
      profiles: profiles,
    );

    expect(paths, hasLength(3));
    expect(paths.first.label, 'Default route');
    expect(paths.first.targetLabel, 'Personal VLESS');
    expect(paths.first.isDefault, isTrue);
    expect(paths.first.hops.map((h) => h.title), contains('LTE node'));

    expect(paths[1].label, '192.168.1.0/24');
    expect(paths[1].targetLabel, contains('Direct'));
    expect(paths[1].hops.map((h) => h.title), contains('Direct'));

    expect(paths[2].label, 'corp.example');
    expect(paths[2].targetLabel, 'Corp via VLESS');
    expect(paths[2].hops.map((h) => h.title), containsAll(['LTE node', 'Corp WG']));
  });
}
