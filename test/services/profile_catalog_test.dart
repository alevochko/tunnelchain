import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/core_config/config_generator.dart';
import 'package:tunnel_chain/core_config/config_invariants.dart';
import 'package:tunnel_chain/core_config/connect_topology.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
import 'package:tunnel_chain/domain/serialization/profile_codec.dart';
import 'package:tunnel_chain/domain/serialization/tunnel_plan_codec.dart';
import 'package:tunnel_chain/services/tunnel_connect_builder.dart';
import 'package:tunnel_chain/services/tunnel_mtu_policy.dart';
import 'package:tunnel_chain/services/tunnel_plan_migration.dart';
import 'package:tunnel_chain/services/tunnel_plan_seeder.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';

void main() {
  test('codec round-trips sample profiles', () {
    const codec = ProfileCodec();
    final encoded = codec.encodeAll(SampleTunnel.profiles.values.toList());
    final decoded = codec.decodeAll(encoded);
    expect(decoded.length, 2);
    expect(decoded.map((p) => p.id).toSet(), SampleTunnel.profiles.keys.toSet());
  });

  test('tunnel plan codec round-trip routing overrides', () {
    const codec = TunnelPlanCodec();
    const chainId = 'chain-test';
    final plan = TunnelPlan(
      chains: const [
        Chain(id: chainId, name: 'Test', hopProfileIds: ['profile-outer']),
      ],
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain(chainId),
        overrides: [
          const RoutingRule(
            order: 0,
            matcher: RuleMatcher(
              type: MatcherType.domainSuffix,
              values: ['.corp.local'],
            ),
            target: RouteTarget.direct(),
          ),
        ],
      ),
    );
    final decoded = codec.decode(codec.encode(plan));
    expect(decoded.effectiveRouting.overrides, hasLength(1));
    expect(
      decoded.effectiveRouting.overrides.first.matcher.type,
      MatcherType.domainSuffix,
    );
  });

  test('tunnel plan codec round-trip', () {
    const codec = TunnelPlanCodec();
    final plan = const TunnelPlanSeeder().seed(
      SampleTunnel.profiles.values.toList(),
    );
    final decoded = codec.decode(codec.encode(plan));
    expect(decoded.chains.length, plan.chains.length);
    expect(
      decoded.effectiveRouting.defaultTarget.chainId,
      plan.effectiveRouting.defaultTarget.chainId,
    );
  });

  test('connect builder single vless hop', () {
    final plan = TunnelPlanMigration.ensureProfiles(
      const TunnelPlanSeeder().seed([SampleTunnel.outerProfile]),
    );
    final bundle = TunnelConnectBuilder().build(
      profiles: [SampleTunnel.outerProfile],
      plan: plan,
    );
    expect(bundle, isNotNull);
    expect(bundle!.chains.length, 1);
    expect(bundle.chains.first.hopProfileIds, ['profile-outer']);
  });

  test('connect builder nested vless + wg', () {
    final profiles = SampleTunnel.profiles.values.toList();
    final plan = TunnelPlanMigration.ensureProfiles(
      const TunnelPlanSeeder().seed(profiles),
    );
    final bundle = TunnelConnectBuilder().build(
      profiles: profiles,
      plan: plan,
    );
    expect(bundle, isNotNull);
    expect(bundle!.chains.length, 2);
    expect(bundle.tunnel.dns.searchDomains, isNotEmpty);
  });

  test('nested without split routes defaults to nested chain', () {
    final inner = SampleTunnel.innerProfile;
    final outer = SampleTunnel.outerProfile;
    final wgOnlyRoutes = WireGuardProfile(
      id: inner.id,
      name: inner.name,
      createdAt: inner.createdAt,
      addresses: inner.addresses,
      privateKeyRef: inner.privateKeyRef,
      peerPublicKey: inner.peerPublicKey,
      presharedKeyRef: inner.presharedKeyRef,
      endpointHost: inner.endpointHost,
      endpointPort: inner.endpointPort,
      dnsServers: inner.dnsServers,
      mtu: inner.mtu,
    );
    final profiles = [outer, wgOnlyRoutes];
    final plan = TunnelPlanMigration.ensureProfiles(
      const TunnelPlanSeeder().seed(profiles),
    );
    final bundle = TunnelConnectBuilder().build(
      profiles: profiles,
      plan: plan,
    );
    expect(bundle, isNotNull);
    expect(
      bundle!.tunnel.routing.defaultTarget.chainId,
      'chain-nested',
    );
    expect(
      () => ConfigGenerator().generate(
        profiles: bundle.profiles,
        chains: bundle.chains,
        tunnel: bundle.tunnel,
        secrets: SampleTunnel.secrets,
      ),
      returnsNormally,
    );
  });

  test('wg-only default chain uses UDP public DNS through tunnel', () {
    const chainId = 'chain-wg';
    final inner = SampleTunnel.innerProfile;
    final wgProfile = WireGuardProfile(
      id: inner.id,
      name: inner.name,
      createdAt: inner.createdAt,
      addresses: inner.addresses,
      privateKeyRef: inner.privateKeyRef,
      peerPublicKey: inner.peerPublicKey,
      presharedKeyRef: inner.presharedKeyRef,
      endpointHost: inner.endpointHost,
      endpointPort: inner.endpointPort,
      dnsServers: inner.dnsServers,
      mtu: inner.mtu,
    );
    final plan = TunnelPlanMigration.ensureProfiles(
      TunnelPlan(
        chains: [
          Chain(
            id: chainId,
            name: 'Work',
            hopProfileIds: [wgProfile.id],
          ),
        ],
        profiles: [
          ConnectionProfile(
            id: 'profile-test',
            name: 'Work',
            routing: RoutingPolicy(
              defaultTarget: const RouteTarget.chain(chainId),
            ),
          ),
        ],
        activeProfileId: 'profile-test',
      ),
    );

    final bundle = TunnelConnectBuilder().build(
      profiles: [wgProfile, SampleTunnel.outerProfile],
      plan: plan,
    );

    expect(bundle, isNotNull);
    expect(
      isNativeWireGuardDefault(
        routing: bundle!.tunnel.routing,
        chains: bundle.chains,
        profiles: bundle.profiles,
      ),
      isTrue,
    );

    expect(bundle!.tunnel.tunMtu, TunnelMtuPolicy.singleHopTunMtuDefault);
    expect(bundle.tunnel.wgMtu, wgProfile.mtu);

    final config = ConfigGenerator().generate(
      profiles: bundle.profiles,
      chains: bundle.chains,
      tunnel: bundle.tunnel,
      secrets: SampleTunnel.secrets,
    );
    expect(config['dns']['final'], 'dns-public');
    final dnsPublic = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public');
    expect(dnsPublic['detour'], 'chain-wg-hop0');
    final rules = config['route']['rules'] as List<dynamic>;
    expect(rules, hasLength(4));
    expect((rules.first as Map)['action'], 'hijack-dns');
    expect(rules[1]['action'], 'resolve');
    final tun = (config['inbounds'] as List).first as Map;
    expect(tun['mtu'], TunnelMtuPolicy.singleHopTunMtuDefault);
    expect(tun['strict_route'], isFalse);
    expect(tun['stack'], 'system');
    final endpoints = config['endpoints'] as List;
    expect((endpoints.first as Map)['mtu'], wgProfile.mtu);
    ConfigInvariants.assertAll(config);
  });

  test('legacy bundle builder still works for samples', () {
    final bundle = const TunnelBundleBuilder().build(
      SampleTunnel.profiles.values.toList(),
    );
    expect(bundle, isNotNull);
    expect(bundle!.chains.length, 2);
  });
}
