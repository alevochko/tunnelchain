import 'dart:convert';

import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/rule_dns.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/target_kind.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/services/tunnel_plan_migration.dart';

class TunnelPlanCodec {
  const TunnelPlanCodec();

  Map<String, dynamic> encode(TunnelPlan plan) {
    final normalized = TunnelPlanMigration.ensureProfiles(plan);
    return {
      'version': 2,
      'chains': normalized.chains.map(encodeChain).toList(),
      'profiles': normalized.profiles.map(encodeProfile).toList(),
      if (normalized.activeProfileId != null)
        'activeProfileId': normalized.activeProfileId,
      'wgMtu': normalized.wgMtu,
      if (normalized.tunMtu != null) 'tunMtu': normalized.tunMtu,
    };
  }

  TunnelPlan decode(Map<String, dynamic> json) {
    final chains = (json['chains'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => decodeChain(Map<String, dynamic>.from(e)))
        .toList();

    final profileMaps = (json['profiles'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => decodeProfile(Map<String, dynamic>.from(e)))
        .toList();

    if (profileMaps.isNotEmpty) {
      return TunnelPlan(
        chains: chains,
        profiles: profileMaps,
        activeProfileId: json['activeProfileId'] as String?,
        wgMtu: json['wgMtu'] as int? ?? 1280,
        tunMtu: json['tunMtu'] as int?,
      );
    }

    final routing = _decodeRouting(
      Map<String, dynamic>.from(json['routing'] as Map? ?? const {}),
    );
    final dns = _decodeDns(
      Map<String, dynamic>.from(json['dns'] as Map? ?? const {}),
    );

    return TunnelPlan(
      chains: chains,
      routing: routing,
      dns: dns,
      wgMtu: json['wgMtu'] as int? ?? 1280,
      tunMtu: json['tunMtu'] as int?,
    );
  }

  Map<String, dynamic> encodeChain(Chain chain) => {
    'id': chain.id,
    'name': chain.name,
    'hopProfileIds': chain.hopProfileIds,
  };

  Chain decodeChain(Map<String, dynamic> json) => Chain(
    id: json['id'] as String,
    name: json['name'] as String,
    hopProfileIds: (json['hopProfileIds'] as List).cast<String>(),
  );

  /// Fingerprint of routing + DNS — used to detect active-profile edits while connected.
  String profileConnectConfigKey(ConnectionProfile profile) =>
      jsonEncode(encodeProfile(profile));

  Map<String, dynamic> encodeProfile(ConnectionProfile profile) => {
    'id': profile.id,
    'name': profile.name,
    'routing': _encodeRouting(profile.routing),
    'dns': _encodeDns(profile.dns),
  };

  ConnectionProfile decodeProfile(Map<String, dynamic> json) =>
      ConnectionProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        routing: _decodeRouting(
          Map<String, dynamic>.from(json['routing'] as Map? ?? const {}),
        ),
        dns: _decodeDns(
          Map<String, dynamic>.from(json['dns'] as Map? ?? const {}),
        ),
      );

  Map<String, dynamic> _encodeRouting(RoutingPolicy routing) => {
    'defaultTarget': _encodeTarget(routing.defaultTarget),
    'overrides': routing.overrides.map(_encodeRule).toList(),
  };

  RoutingPolicy _decodeRouting(Map<String, dynamic> json) => RoutingPolicy(
    defaultTarget: _decodeTarget(
      Map<String, dynamic>.from(json['defaultTarget'] as Map? ?? const {}),
    ),
    overrides: (json['overrides'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _decodeRule(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> _encodeRule(RoutingRule rule) => {
    'order': rule.order,
    'matcher': {
      'type': rule.matcher.type.name,
      'values': rule.matcher.values,
    },
    'target': _encodeTarget(rule.target),
    if (rule.dns != null) 'dns': _encodeRuleDns(rule.dns!),
  };

  RoutingRule _decodeRule(Map<String, dynamic> json) => RoutingRule(
    order: json['order'] as int? ?? 0,
    matcher: RuleMatcher(
      type: MatcherType.values.byName(json['matcher']['type'] as String),
      values: (json['matcher']['values'] as List).cast<String>(),
    ),
    target: _decodeTarget(Map<String, dynamic>.from(json['target'] as Map)),
    dns: json['dns'] == null
        ? null
        : _decodeRuleDns(Map<String, dynamic>.from(json['dns'] as Map)),
  );

  Map<String, dynamic> _encodeRuleDns(RuleDns dns) => {
    'server': dns.server,
    'transport': dns.transport.name,
    'viaChain': dns.viaChain,
  };

  RuleDns _decodeRuleDns(Map<String, dynamic> json) => RuleDns(
    server: json['server'] as String,
    transport: DnsTransport.values.byName(
      json['transport'] as String? ?? 'udp',
    ),
    viaChain: json['viaChain'] as bool? ?? true,
  );

  Map<String, dynamic> _encodeTarget(RouteTarget target) => {
    'kind': target.kind.name,
    if (target.chainId != null) 'chainId': target.chainId,
  };

  RouteTarget _decodeTarget(Map<String, dynamic> json) {
    final kind = TargetKind.values.byName(json['kind'] as String? ?? 'chain');
    if (kind == TargetKind.direct) return const RouteTarget.direct();
    return RouteTarget.chain(json['chainId'] as String);
  }

  Map<String, dynamic> _encodeDns(DnsPolicy dns) => {
    'publicResolver': dns.publicResolver,
    'defaultUpstreamTag': dns.defaultUpstreamTag,
    'includeReverseZones': dns.includeReverseZones,
    'searchDomains': dns.searchDomains,
    'upstreams': dns.upstreams.map(_encodeUpstream).toList(),
    'suffixRules': dns.suffixRules.map(_encodeSuffixRule).toList(),
  };

  DnsPolicy _decodeDns(Map<String, dynamic> json) {
    final raw = json['publicResolver'] as String? ?? '1.1.1.1';
    return DnsPolicy(
      publicResolver: formatPublicResolvers(parsePublicResolvers(raw)),
      defaultUpstreamTag: json['defaultUpstreamTag'] as String? ?? 'dns-public',
      includeReverseZones: json['includeReverseZones'] as bool? ?? false,
      searchDomains: (json['searchDomains'] as List?)?.cast<String>() ?? const [],
      upstreams: (json['upstreams'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => _decodeUpstream(Map<String, dynamic>.from(e)))
          .toList(),
      suffixRules: (json['suffixRules'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => _decodeSuffixRule(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> _encodeUpstream(DnsUpstream u) => {
    'tag': u.tag,
    'server': u.server,
    'transport': u.transport.name,
    if (u.viaChainId != null) 'viaChainId': u.viaChainId,
  };

  DnsUpstream _decodeUpstream(Map<String, dynamic> json) => DnsUpstream(
    tag: json['tag'] as String,
    server: json['server'] as String,
    transport: DnsTransport.values.byName(json['transport'] as String),
    viaChainId: json['viaChainId'] as String?,
  );

  Map<String, dynamic> _encodeSuffixRule(DnsSuffixRule rule) => {
    'suffixes': rule.suffixes,
    'upstreamTag': rule.upstreamTag,
  };

  DnsSuffixRule _decodeSuffixRule(Map<String, dynamic> json) => DnsSuffixRule(
    suffixes: (json['suffixes'] as List).cast<String>(),
    upstreamTag: json['upstreamTag'] as String,
  );
}
