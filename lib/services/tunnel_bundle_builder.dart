import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Profiles + chains + tunnel settings ready for [ConfigGenerator].
class ConnectBundle {
  const ConnectBundle({
    required this.profiles,
    required this.chains,
    required this.tunnel,
  });

  final Map<String, Profile> profiles;
  final List<Chain> chains;
  final TunnelConfig tunnel;

  Chain? chainById(String? id) {
    if (id == null) return null;
    for (final chain in chains) {
      if (chain.id == id) return chain;
    }
    return null;
  }

  /// Label for the default route row (Direct or chain name).
  String defaultRouteLabel() {
    final target = tunnel.routing.defaultTarget;
    if (target.isDirect) return 'Direct';
    return chainById(target.chainId)?.name ?? target.chainId ?? '—';
  }

  /// Primary chain when default route is a chain; otherwise [activeProfileName].
  String activeChainLabel({String? activeProfileName}) {
    final target = tunnel.routing.defaultTarget;
    if (!target.isDirect) {
      return chainById(target.chainId)?.name ?? '—';
    }
    return activeProfileName ?? 'Direct';
  }

  String? defaultChainName() {
    final id = tunnel.routing.defaultTarget.chainId;
    if (id == null) return null;
    return chainById(id)?.name;
  }

  List<String> layerLabelsForPlan(TunnelPlan plan) {
    final chain = plan.primaryDisplayChain();
    if (chain == null) return const ['Application', 'Egress'];
    final labels = <String>['Application'];
    for (final hopId in chain.hopProfileIds.reversed) {
      labels.add(profiles[hopId]?.name ?? hopId);
    }
    labels.add('Egress');
    return labels;
  }

  WireGuardProfile? innerWireGuardProfile() {
    for (final profile in profiles.values) {
      if (profile is WireGuardProfile) return profile;
    }
    return null;
  }

  VlessProfile? outerVlessProfile() {
    for (final profile in profiles.values) {
      if (profile is VlessProfile) return profile;
    }
    return null;
  }
}

class TunnelBundleBuilder {
  const TunnelBundleBuilder();

  /// Builds a connect bundle from imported profiles.
  ///
  /// Requires at least one VLESS profile (outer hop). If a WireGuard profile
  /// exists, builds a nested chain with split routing like the sample topology.
  ConnectBundle? build(List<Profile> profiles) {
    if (profiles.isEmpty) return null;

    final vless = profiles.whereType<VlessProfile>().toList();
    final wireGuard = profiles.whereType<WireGuardProfile>().toList();
    if (vless.isEmpty) return null;

    final profileMap = {for (final p in profiles) p.id: p};
    final outer = vless.first;

    if (wireGuard.isEmpty) {
      const chainId = 'chain-default';
      return ConnectBundle(
        profiles: profileMap,
        chains: [
          Chain(id: chainId, name: outer.name, hopProfileIds: [outer.id]),
        ],
        tunnel: TunnelConfig(
          routing: RoutingPolicy(
            defaultTarget: const RouteTarget.chain(chainId),
          ),
          dns: const DnsPolicy(),
          clashApiSecret: _clashSecret,
        ),
      );
    }

    final inner = wireGuard.first;
    const outerChainId = 'chain-outer';
    const nestedChainId = 'chain-nested';

    final hasSplitRoutes =
        inner.allowedIps.isNotEmpty || inner.searchDomains.isNotEmpty;

    final overrides = <RoutingRule>[];
    if (inner.allowedIps.isNotEmpty) {
      overrides.add(
        RoutingRule(
          order: overrides.length,
          matcher: RuleMatcher(
            type: MatcherType.ipCidr,
            values: inner.allowedIps,
          ),
          target: const RouteTarget.chain(nestedChainId),
        ),
      );
    }
    if (inner.searchDomains.isNotEmpty) {
      overrides.add(
        RoutingRule(
          order: overrides.length,
          matcher: RuleMatcher(
            type: MatcherType.domainSuffix,
            values: inner.searchDomains,
          ),
          target: const RouteTarget.chain(nestedChainId),
        ),
      );
    }

    // Without split routes from the .conf, send all traffic through the nested
    // chain so inner WireGuard + internal DNS stay reachable.
    final defaultChainId = hasSplitRoutes ? outerChainId : nestedChainId;

    final dnsServer = inner.primaryDnsServer;
    final dnsUpstreams = dnsServer != null
        ? [
            DnsUpstream(
              tag: 'dns-internal',
              server: dnsServer,
              transport: DnsTransport.udp,
              viaChainId: nestedChainId,
            ),
          ]
        : const <DnsUpstream>[];

    final dnsSuffixRules = inner.searchDomains.isNotEmpty
        ? [
            DnsSuffixRule(
              suffixes: inner.searchDomains,
              upstreamTag: 'dns-internal',
            ),
          ]
        : const <DnsSuffixRule>[];

    return ConnectBundle(
      profiles: profileMap,
      chains: [
        Chain(
          id: outerChainId,
          name: outer.name,
          hopProfileIds: [outer.id],
        ),
        Chain(
          id: nestedChainId,
          name: '${outer.name} → ${inner.name}',
          hopProfileIds: [outer.id, inner.id],
        ),
      ],
      tunnel: TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: RouteTarget.chain(defaultChainId),
          overrides: overrides,
        ),
        dns: DnsPolicy(
          suffixRules: dnsSuffixRules,
          upstreams: dnsUpstreams,
          includeReverseZones: inner.searchDomains.isNotEmpty,
          searchDomains: inner.searchDomains,
        ),
        wgMtu: inner.mtu,
        clashApiSecret: _clashSecret,
      ),
    );
  }

  static const _clashSecret = 'tunnelchain-dev-secret';
}
