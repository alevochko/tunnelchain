import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';

/// Shared chains plus per-profile routing and DNS.
class TunnelPlan {
  const TunnelPlan({
    this.chains = const [],
    this.profiles = const [],
    this.activeProfileId,
    this.routing = const RoutingPolicy(defaultTarget: RouteTarget.direct()),
    this.dns = const DnsPolicy(),
    this.wgMtu = 1280,
    this.tunMtu,
  });

  final List<Chain> chains;
  final List<ConnectionProfile> profiles;
  final String? activeProfileId;

  /// Legacy top-level routing — used only when [profiles] is empty.
  final RoutingPolicy routing;
  final DnsPolicy dns;
  final int wgMtu;
  final int? tunMtu;

  ConnectionProfile? get activeProfile {
    if (profiles.isEmpty) return null;
    final id = activeProfileId ?? profiles.first.id;
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return profiles.first;
  }

  RoutingPolicy get effectiveRouting =>
      activeProfile?.routing ?? routing;

  DnsPolicy get effectiveDns => activeProfile?.dns ?? dns;

  Chain? chainById(String? id) {
    if (id == null) return null;
    for (final chain in chains) {
      if (chain.id == id) return chain;
    }
    return null;
  }

  Chain? defaultChain() {
    final id = effectiveRouting.defaultTarget.chainId;
    return chainById(id);
  }

  /// Chain for status visualization: default chain, or first override chain.
  Chain? primaryDisplayChain() {
    final direct = defaultChain();
    if (direct != null) return direct;
    for (final rule in effectiveRouting.sortedOverrides()) {
      final chain = chainById(rule.target.chainId);
      if (chain != null) return chain;
    }
    return null;
  }

  /// Chains referenced by the active profile routing rules.
  List<Chain> activeProfileChains() {
    final profile = activeProfile;
    if (profile == null) return const [];
    final ids = profile.referencedChainIds();
    return chains.where((c) => ids.contains(c.id)).toList();
  }

  Set<String> activeRoutingChainIds() {
    final profile = activeProfile;
    if (profile == null) return {};
    return profile.referencedChainIds();
  }

  TunnelPlan copyWith({
    List<Chain>? chains,
    List<ConnectionProfile>? profiles,
    String? activeProfileId,
    bool clearActiveProfileId = false,
    RoutingPolicy? routing,
    DnsPolicy? dns,
    int? wgMtu,
    int? tunMtu,
    bool clearTunMtu = false,
  }) {
    return TunnelPlan(
      chains: chains ?? this.chains,
      profiles: profiles ?? this.profiles,
      activeProfileId: clearActiveProfileId
          ? null
          : (activeProfileId ?? this.activeProfileId),
      routing: routing ?? this.routing,
      dns: dns ?? this.dns,
      wgMtu: wgMtu ?? this.wgMtu,
      tunMtu: clearTunMtu ? null : (tunMtu ?? this.tunMtu),
    );
  }

  TunnelPlan updateActiveProfile(
    ConnectionProfile Function(ConnectionProfile profile) update,
  ) {
    final active = activeProfile;
    if (active == null) return this;
    final next = profiles
        .map((p) => p.id == active.id ? update(p) : p)
        .toList(growable: false);
    return copyWith(profiles: next);
  }
}
