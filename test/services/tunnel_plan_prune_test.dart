import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/services/tunnel_plan_migration.dart';

/// Mirrors [TunnelCatalogNotifier._prunePlan] for regression tests.
TunnelPlan prunePlanForNodes(TunnelPlan plan, Set<String> nodeIds) {
  final nodeMap = {for (final id in nodeIds) id: true};
  final chains = <Chain>[];
  for (final chain in plan.chains) {
    final hops =
        chain.hopProfileIds.where((id) => nodeMap.containsKey(id)).toList();
    if (hops.isNotEmpty) {
      chains.add(Chain(id: chain.id, name: chain.name, hopProfileIds: hops));
    }
  }

  final chainIds = chains.map((c) => c.id).toSet();
  var next = TunnelPlanMigration.ensureProfiles(plan.copyWith(chains: chains));

  final profiles = next.profiles
      .map((p) => TunnelPlanMigration.repairProfileRouting(p, chainIds))
      .toList();

  return next.copyWith(profiles: profiles);
}

void main() {
  test('empty node ids must not drop chains when pruning is skipped at load', () {
    const plan = TunnelPlan(
      chains: [
        Chain(
          id: 'chain-1',
          name: 'VLESS',
          hopProfileIds: ['node-1'],
        ),
      ],
      profiles: [
        ConnectionProfile(
          id: 'profile-1',
          name: 'Default',
          routing: RoutingPolicy(
            defaultTarget: RouteTarget.chain('chain-1'),
          ),
        ),
      ],
    );

    // Pruning with zero nodes removes chains — this is why load must wait
    // for the profile catalog before calling prune.
    final pruned = prunePlanForNodes(plan, {});
    expect(pruned.chains, isEmpty);

    final kept = prunePlanForNodes(plan, {'node-1'});
    expect(kept.chains, hasLength(1));
    expect(kept.chains.first.hopProfileIds, ['node-1']);
  });
}
