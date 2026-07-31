import 'package:tunnel_chain/core_config/connect_topology.dart' as topology;
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/target_kind.dart';

/// Derived sing-box layout from routing + chains — single source for variant flags.
class SingBoxTopology {
  const SingBoxTopology({
    required this.referencedChainIds,
    required this.defaultChain,
    required this.defaultOutbound,
    required this.splitRouting,
    required this.wgOnlyDefault,
    required this.vlessOnlyDefault,
    required this.nestedDefault,
    required this.launcherTun,
    required this.domainRouting,
  });

  final Set<String> referencedChainIds;
  final Chain? defaultChain;
  final String defaultOutbound;
  final bool splitRouting;
  final bool wgOnlyDefault;
  final bool vlessOnlyDefault;
  final bool nestedDefault;
  final bool launcherTun;
  final bool domainRouting;

  /// Launcher-style resolve/sniff on TUN for domain suffix rules or single-hop default.
  bool get useTunResolveSniff =>
      (launcherTun && !nestedDefault) || domainRouting;

  bool get strictRoute => !(wgOnlyDefault || splitRouting);

  bool get findProcess => wgOnlyDefault;

  factory SingBoxTopology.compute({
    required RoutingPolicy routing,
    required List<Chain> chains,
    required Map<String, Profile> profiles,
    required Map<String, String> hopTags,
    required Set<String> referenced,
  }) {
    return SingBoxTopology(
      referencedChainIds: referenced,
      defaultChain: topology.defaultChain(routing: routing, chains: chains),
      defaultOutbound: _defaultOutbound(routing.defaultTarget, hopTags),
      splitRouting: routing.defaultTarget.isDirect && referenced.isNotEmpty,
      wgOnlyDefault: topology.isNativeWireGuardDefault(
        routing: routing,
        chains: chains,
        profiles: profiles,
      ),
      vlessOnlyDefault: topology.isVlessOnlyDefault(
        routing: routing,
        chains: chains,
        profiles: profiles,
      ),
      nestedDefault: topology.isNestedDefault(routing: routing, chains: chains),
      launcherTun: topology.usesLauncherTunTemplate(
        routing: routing,
        chains: chains,
      ),
      domainRouting: topology.needsDomainBasedRouting(routing),
    );
  }

  static String _defaultOutbound(
    RouteTarget target,
    Map<String, String> hopTags,
  ) {
    if (target.isDirect) return SingBoxTags.direct;
    final chainId = target.chainId;
    if (chainId == null) {
      throw StateError('Chain target without chainId');
    }
    final tag = hopTags[chainId];
    if (tag == null) {
      throw StateError('No hop tag for chain $chainId');
    }
    return tag;
  }

  String outboundFor(RouteTarget target, Map<String, String> hopTags) {
    if (target.isDirect) return SingBoxTags.direct;
    final chainId = target.chainId;
    if (chainId == null) throw StateError('Chain target without chainId');
    final tag = hopTags[chainId];
    if (tag == null) throw StateError('No hop tag for chain $chainId');
    return tag;
  }
}
