import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/services/tunnel_mtu_policy.dart';

void main() {
  final wg = WireGuardProfile(
    id: 'wg-1',
    name: 'Germany',
    createdAt: DateTime(2026),
    addresses: ['10.0.0.1/32'],
    privateKeyRef: const SecretRef('k'),
    peerPublicKey: 'pk',
    endpointHost: '1.2.3.4',
    endpointPort: 51820,
    mtu: 1420,
  );

  const wgOnlyChain = Chain(
    id: 'chain-wg',
    name: 'Work',
    hopProfileIds: ['wg-1'],
  );

  const nestedChain = Chain(
    id: 'chain-nested',
    name: 'VLESS+WG',
    hopProfileIds: ['vless-1', 'wg-1'],
  );

  test('wg-only uses launcher TUN mtu when plan has no override', () {
    const plan = TunnelPlan(
      chains: [wgOnlyChain],
      routing: RoutingPolicy(
        defaultTarget: RouteTarget.chain('chain-wg'),
      ),
      wgMtu: 1280,
    );

    expect(
      TunnelMtuPolicy.resolveTunMtu(
        plan: plan,
        defaultChain: wgOnlyChain,
        wireGuard: wg,
      ),
      1492,
    );
    expect(
      TunnelMtuPolicy.resolveWgMtu(plan: plan, wireGuard: wg),
      1420,
    );
  });

  test('nested chain uses plan wgMtu for TUN', () {
    const plan = TunnelPlan(
      chains: [nestedChain],
      routing: RoutingPolicy(
        defaultTarget: RouteTarget.chain('chain-nested'),
      ),
      wgMtu: 1280,
    );

    expect(
      TunnelMtuPolicy.resolveTunMtu(
        plan: plan,
        defaultChain: nestedChain,
        wireGuard: wg,
      ),
      1280,
    );
  });

  test('plan tunMtu override wins', () {
    const plan = TunnelPlan(
      chains: [wgOnlyChain],
      routing: RoutingPolicy(
        defaultTarget: RouteTarget.chain('chain-wg'),
      ),
      wgMtu: 1280,
      tunMtu: 1360,
    );

    expect(
      TunnelMtuPolicy.resolveTunMtu(
        plan: plan,
        defaultChain: wgOnlyChain,
        wireGuard: wg,
      ),
      1360,
    );
  });
}
