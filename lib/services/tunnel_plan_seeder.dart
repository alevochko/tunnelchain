import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Test helper: builds a sample [TunnelPlan] from profiles (not used at runtime).
class TunnelPlanSeeder {
  const TunnelPlanSeeder();

  TunnelPlan seed(List<Profile> profiles) {
    if (profiles.isEmpty) return const TunnelPlan();

    final vless = profiles.whereType<VlessProfile>().toList();
    final wireGuard = profiles.whereType<WireGuardProfile>().toList();
    if (vless.isEmpty) return const TunnelPlan();

    final chains = <Chain>[];
    final outer = vless.first;

    const singleId = 'chain-vless';
    chains.add(Chain(id: singleId, name: outer.name, hopProfileIds: [outer.id]));

    if (wireGuard.isEmpty) {
      return TunnelPlan(
        chains: chains,
        routing: RoutingPolicy(
          defaultTarget: const RouteTarget.chain(singleId),
        ),
      );
    }

    final inner = wireGuard.first;
    const nestedId = 'chain-nested';
    chains.add(
      Chain(
        id: nestedId,
        name: '${outer.name} → ${inner.name}',
        hopProfileIds: [outer.id, inner.id],
      ),
    );

    final overrides = <RoutingRule>[];
    if (inner.allowedIps.isNotEmpty) {
      overrides.add(
        RoutingRule(
          order: 0,
          matcher: RuleMatcher(
            type: MatcherType.ipCidr,
            values: inner.allowedIps,
          ),
          target: const RouteTarget.chain(nestedId),
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
          target: const RouteTarget.chain(nestedId),
        ),
      );
    }

    final hasSplit = overrides.isNotEmpty;
    final defaultId = hasSplit ? singleId : nestedId;

    final dnsServer = inner.primaryDnsServer;
    final dnsUpstreams = dnsServer != null
        ? [
            DnsUpstream(
              tag: 'dns-internal',
              server: dnsServer,
              transport: DnsTransport.udp,
              viaChainId: nestedId,
            ),
          ]
        : const <DnsUpstream>[];

    return TunnelPlan(
      chains: chains,
      routing: RoutingPolicy(
        defaultTarget: RouteTarget.chain(defaultId),
        overrides: overrides,
      ),
      dns: DnsPolicy(
        suffixRules: inner.searchDomains.isNotEmpty
            ? [
                DnsSuffixRule(
                  suffixes: inner.searchDomains,
                  upstreamTag: 'dns-internal',
                ),
              ]
            : const [],
        upstreams: dnsUpstreams,
        includeReverseZones: inner.searchDomains.isNotEmpty,
        searchDomains: inner.searchDomains,
      ),
      wgMtu: inner.mtu,
    );
  }
}
