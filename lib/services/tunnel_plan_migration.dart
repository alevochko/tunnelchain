import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';

/// Builds or repairs [ConnectionProfile] list from legacy plan data.
abstract final class TunnelPlanMigration {
  static TunnelPlan ensureProfiles(TunnelPlan plan) {
    if (plan.chains.isEmpty && plan.profiles.isEmpty) {
      return plan.copyWith(clearActiveProfileId: true);
    }

    if (plan.profiles.isEmpty) {
      return _fromLegacy(plan);
    }

    final chainIds = plan.chains.map((c) => c.id).toSet();
    final profiles = plan.profiles
        .map((profile) => _repairProfile(profile, chainIds))
        .toList();

    if (profiles.isEmpty) {
      return plan.chains.isEmpty
          ? plan.copyWith(profiles: const [], clearActiveProfileId: true)
          : _fromLegacy(plan.copyWith(profiles: const []));
    }

    final activeId = profiles.any((p) => p.id == plan.activeProfileId)
        ? plan.activeProfileId!
        : profiles.first.id;

    return plan.copyWith(profiles: profiles, activeProfileId: activeId);
  }

  static ConnectionProfile repairProfileRouting(
    ConnectionProfile profile,
    Set<String> chainIds,
  ) => _repairProfile(profile, chainIds);

  static ConnectionProfile _repairProfile(
    ConnectionProfile profile,
    Set<String> chainIds,
  ) {
    var routing = profile.routing;
    final defaultChainId = routing.defaultTarget.chainId;
    if (defaultChainId != null && !chainIds.contains(defaultChainId)) {
      routing = RoutingPolicy(
        defaultTarget: const RouteTarget.direct(),
        overrides: routing.overrides
            .where(
              (r) =>
                  r.target.isDirect ||
                  chainIds.contains(r.target.chainId),
            )
            .toList(),
      );
    } else {
      routing = RoutingPolicy(
        defaultTarget: routing.defaultTarget,
        overrides: routing.overrides
            .where(
              (r) =>
                  r.target.isDirect ||
                  chainIds.contains(r.target.chainId),
            )
            .toList(),
      );
    }

    return profile.copyWith(
      routing: routing,
      dns: DnsPolicy(
        publicResolver: formatPublicResolvers(
          parsePublicResolvers(profile.dns.publicResolver),
        ),
        defaultUpstreamTag: profile.dns.defaultUpstreamTag,
        includeReverseZones: profile.dns.includeReverseZones,
        searchDomains: profile.dns.searchDomains,
        upstreams: profile.dns.upstreams,
        suffixRules: profile.dns.suffixRules,
      ),
    );
  }

  static TunnelPlan _fromLegacy(TunnelPlan plan) {
    if (plan.chains.isEmpty) {
      return plan.copyWith(profiles: const [], clearActiveProfileId: true);
    }

    final defaultChainId = plan.routing.defaultTarget.chainId;
    final defaultTarget = defaultChainId != null &&
            plan.chains.any((c) => c.id == defaultChainId)
        ? plan.routing.defaultTarget
        : (plan.chains.length == 1
            ? RouteTarget.chain(plan.chains.first.id)
            : const RouteTarget.direct());

    final profile = ConnectionProfile(
      id: 'profile-default',
      name: 'Default',
      routing: RoutingPolicy(
        defaultTarget: defaultTarget,
        overrides: plan.routing.overrides,
      ),
      dns: plan.dns,
    );

    return plan.copyWith(
      profiles: [profile],
      activeProfileId: profile.id,
    );
  }
}
