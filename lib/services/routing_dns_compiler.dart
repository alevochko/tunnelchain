import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/rule_dns.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Merges per-rule DNS from [routing] into a sing-box-ready [DnsPolicy].
abstract final class RoutingDnsCompiler {
  static String upstreamTagForRule(int order) => 'dns-rule-$order';

  static DnsPolicy compile({
    required DnsPolicy base,
    required RoutingPolicy routing,
    List<Chain> chains = const [],
    Map<String, Profile> profiles = const {},
  }) {
    final upstreams = List<DnsUpstream>.from(base.upstreams);
    final suffixRules = List<DnsSuffixRule>.from(base.suffixRules);
    final tags = upstreams.map((u) => u.tag).toSet();

    for (final rule in routing.sortedOverrides()) {
      if (rule.matcher.type != MatcherType.domainSuffix) continue;

      final effectiveDns = rule.dns ??
          _implicitDnsForRule(
            rule: rule,
            chains: chains,
            profiles: profiles,
          );
      if (effectiveDns == null) continue;

      final resolvers = parsePublicResolvers(effectiveDns.server);
      if (resolvers.isEmpty) continue;

      String? viaChainId;
      if (effectiveDns.viaChain && !rule.target.isDirect) {
        viaChainId = rule.target.chainId;
      }

      for (var i = 0; i < resolvers.length; i++) {
        final tag = i == 0
            ? upstreamTagForRule(rule.order)
            : '${upstreamTagForRule(rule.order)}-${i + 1}';
        if (tags.contains(tag)) continue;
        tags.add(tag);

        upstreams.add(
          DnsUpstream(
            tag: tag,
            server: resolvers[i],
            transport: effectiveDns.transport,
            viaChainId: viaChainId,
          ),
        );
      }

      suffixRules.add(
        DnsSuffixRule(
          suffixes: rule.matcher.values,
          upstreamTag: upstreamTagForRule(rule.order),
        ),
      );
    }

    final addedRules = suffixRules.length > base.suffixRules.length;

    return DnsPolicy(
      publicResolver: base.publicResolver,
      upstreams: upstreams,
      suffixRules: suffixRules,
      defaultUpstreamTag: base.defaultUpstreamTag,
      includeReverseZones: base.includeReverseZones || addedRules,
      searchDomains: base.searchDomains,
    );
  }

  static RuleDns? _implicitDnsForRule({
    required RoutingRule rule,
    required List<Chain> chains,
    required Map<String, Profile> profiles,
  }) {
    if (rule.target.isDirect) return null;
    final chainId = rule.target.chainId;
    if (chainId == null) return null;

    final wg = _wireGuardInChain(chainId, chains, profiles);
    if (wg == null || wg.dnsServers.isEmpty) return null;

    return RuleDns(
      server: formatPublicResolvers(wg.dnsServers),
      transport: DnsTransport.udp,
      viaChain: true,
    );
  }

  static WireGuardProfile? _wireGuardInChain(
    String chainId,
    List<Chain> chains,
    Map<String, Profile> profiles,
  ) {
    for (final chain in chains) {
      if (chain.id != chainId) continue;
      for (final hopId in chain.hopProfileIds.reversed) {
        final profile = profiles[hopId];
        if (profile is WireGuardProfile) return profile;
      }
    }
    return null;
  }
}
