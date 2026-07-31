import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/domain/validators/chain_validator.dart';
import 'package:tunnel_chain/domain/validators/routing_validator.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';
import 'package:tunnel_chain/services/tunnel_mtu_policy.dart';

/// Builds a [ConnectBundle] from user-defined plan + imported profiles.
class TunnelConnectBuilder {
  TunnelConnectBuilder({
    ChainValidator? chainValidator,
    RoutingValidator? routingValidator,
  }) : _chainValidator = chainValidator ?? ChainValidator(),
       _routingValidator = routingValidator ?? RoutingValidator();

  final ChainValidator _chainValidator;
  final RoutingValidator _routingValidator;

  static const clashSecret = 'tunnelchain-dev-secret';

  ConnectBundle? build({
    required List<Profile> profiles,
    required TunnelPlan plan,
  }) {
    if (profiles.isEmpty) return null;

    final active = plan.activeProfile;
    if (active == null) return null;

    final profileMap = {for (final p in profiles) p.id: p};
    final referencedIds = active.referencedChainIds();
    final chains = plan.chains
        .where((chain) => referencedIds.contains(chain.id))
        .toList();

    for (final chain in chains) {
      _chainValidator.validate(chain, profileMap);
    }

    final chainIds = {for (final c in chains) c.id};
    _routingValidator.validate(plan.effectiveRouting, chainIds);

    final defaultChain = plan.defaultChain();
    if (defaultChain == null && !plan.effectiveRouting.defaultTarget.isDirect) {
      return null;
    }

    if (chains.isEmpty && plan.effectiveRouting.referencedChainIds().isNotEmpty) {
      return null;
    }

    return ConnectBundle(
      profiles: profileMap,
      chains: chains,
      tunnel: _enrichTunnel(plan: plan, profiles: profileMap),
    );
  }

  /// Fills DNS/MTU from WireGuard profile metadata and [TunnelPlan] overrides.
  TunnelConfig _enrichTunnel({
    required TunnelPlan plan,
    required Map<String, Profile> profiles,
  }) {
    var dns = plan.activeProfile?.compiledDns(
          chains: plan.chains,
          profiles: profiles,
        ) ??
        plan.effectiveDns;

    final defaultChain = plan.defaultChain();
    final wg = defaultChain == null
        ? null
        : _wireGuardInChain(defaultChain, profiles);

    final tunMtu = TunnelMtuPolicy.resolveTunMtu(
      plan: plan,
      defaultChain: defaultChain,
      wireGuard: wg,
    );
    final wgMtu = TunnelMtuPolicy.resolveWgMtu(plan: plan, wireGuard: wg);

    if (defaultChain == null) {
      return TunnelConfig(
        routing: plan.effectiveRouting,
        dns: dns,
        tunMtu: tunMtu,
        wgMtu: wgMtu,
        clashApiSecret: clashSecret,
      );
    }

    if (wg != null) {
      final corpDns = wg.primaryDnsServer;
      final viaChainId = defaultChain.hopProfileIds.contains(wg.id)
          ? defaultChain.id
          : _chainIdForProfile(plan, wg.id);

      if (corpDns != null &&
          viaChainId != null &&
          wg.searchDomains.isNotEmpty &&
          !dns.upstreams.any((u) => u.tag == 'dns-internal')) {
        dns = DnsPolicy(
          publicResolver: dns.publicResolver,
          upstreams: [
            ...dns.upstreams,
            DnsUpstream(
              tag: 'dns-internal',
              server: corpDns,
              transport: DnsTransport.udp,
              viaChainId: viaChainId,
            ),
          ],
          suffixRules: [
            ...dns.suffixRules,
            DnsSuffixRule(
              suffixes: wg.searchDomains,
              upstreamTag: 'dns-internal',
            ),
          ],
          defaultUpstreamTag: dns.defaultUpstreamTag,
          includeReverseZones: true,
          searchDomains: wg.searchDomains,
        );
      }
    }

    return TunnelConfig(
      routing: plan.effectiveRouting,
      dns: dns,
      tunMtu: tunMtu,
      wgMtu: wgMtu,
      clashApiSecret: clashSecret,
    );
  }

  WireGuardProfile? _wireGuardInChain(
    Chain chain,
    Map<String, Profile> profiles,
  ) {
    for (final id in chain.hopProfileIds.reversed) {
      final profile = profiles[id];
      if (profile is WireGuardProfile) return profile;
    }
    return null;
  }

  String? _chainIdForProfile(TunnelPlan plan, String profileId) {
    for (final chain in plan.chains) {
      if (chain.hopProfileIds.contains(profileId)) return chain.id;
    }
    return null;
  }

  Chain? activeChain(TunnelPlan plan) => plan.defaultChain();

  List<String> layerLabels({
    required TunnelPlan plan,
    required Map<String, Profile> profiles,
  }) {
    final chain = plan.defaultChain();
    if (chain == null) return const ['Application', 'Egress'];
    final labels = <String>['Application'];
    for (final hopId in chain.hopProfileIds.reversed) {
      labels.add(profiles[hopId]?.name ?? hopId);
    }
    labels.add('Egress');
    return labels;
  }
}
