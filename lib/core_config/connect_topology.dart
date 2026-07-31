import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

Chain? defaultChain({
  required RoutingPolicy routing,
  required List<Chain> chains,
}) {
  final chainId = routing.defaultTarget.chainId;
  if (chainId == null) return null;
  for (final c in chains) {
    if (c.id == chainId) return c;
  }
  return null;
}

Profile? defaultHopProfile({
  required RoutingPolicy routing,
  required List<Chain> chains,
  required Map<String, Profile> profiles,
}) {
  final chain = defaultChain(routing: routing, chains: chains);
  if (chain == null || chain.hopProfileIds.isEmpty) return null;
  return profiles[chain.hopProfileIds.first];
}

/// Default route is a single-hop chain (WG or VLESS) — singbox-launcher TUN template.
bool isSingleHopDefault({
  required RoutingPolicy routing,
  required List<Chain> chains,
}) {
  final chain = defaultChain(routing: routing, chains: chains);
  return chain != null && chain.hopProfileIds.length == 1;
}

/// Default route is a single-hop WireGuard chain.
bool isNativeWireGuardDefault({
  required RoutingPolicy routing,
  required List<Chain> chains,
  required Map<String, Profile> profiles,
}) {
  if (!isSingleHopDefault(routing: routing, chains: chains)) return false;
  return defaultHopProfile(
        routing: routing,
        chains: chains,
        profiles: profiles,
      )
      is WireGuardProfile;
}

/// Default route is a multi-hop chain (e.g. VLESS → WireGuard).
bool isNestedDefault({
  required RoutingPolicy routing,
  required List<Chain> chains,
}) {
  final chain = defaultChain(routing: routing, chains: chains);
  return chain != null && chain.hopProfileIds.length >= 2;
}

/// singbox-launcher TUN template (system stack, resolve/sniff/hijack route).
bool usesLauncherTunTemplate({
  required RoutingPolicy routing,
  required List<Chain> chains,
}) {
  return isSingleHopDefault(routing: routing, chains: chains) ||
      isNestedDefault(routing: routing, chains: chains);
}

/// Default route is a single-hop VLESS chain.
bool isVlessOnlyDefault({
  required RoutingPolicy routing,
  required List<Chain> chains,
  required Map<String, Profile> profiles,
}) {
  if (!isSingleHopDefault(routing: routing, chains: chains)) return false;
  return defaultHopProfile(
        routing: routing,
        chains: chains,
        profiles: profiles,
      )
      is VlessProfile;
}

/// Split routing that matches domains needs TUN resolve/sniff for suffix rules.
bool needsDomainBasedRouting(RoutingPolicy routing) {
  return routing.overrides.any(
    (rule) => rule.matcher.type == MatcherType.domainSuffix,
  );
}
