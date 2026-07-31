import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_topology.dart';
import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';

/// Builds the `route` section.
class SingBoxRouteConfigurator {
  Map<String, dynamic> build({
    required TunnelConfig tunnel,
    required SingBoxTopology topology,
    required Map<String, String> hopTags,
  }) {
    final rules = <Map<String, dynamic>>[
      if (topology.useTunResolveSniff) ...[
        _dnsPinHijack,
        {
          'inbound': SingBoxTags.tunInbound,
          'action': 'resolve',
          'strategy': 'prefer_ipv4',
        },
        {
          'inbound': SingBoxTags.tunInbound,
          'action': 'sniff',
          'timeout': '1s',
        },
        {'protocol': 'dns', 'action': 'hijack-dns'},
      ] else ...[
        _dnsPinHijack,
        {'action': 'sniff'},
        {'protocol': 'dns', 'action': 'hijack-dns'},
      ],
      ..._splitCorpCidrRules(tunnel: tunnel, hopTags: hopTags),
      if (topology.defaultOutbound == SingBoxTags.direct)
        {'ip_is_private': true, 'outbound': SingBoxTags.direct},
    ];

    for (final rule in tunnel.routing.sortedOverrides()) {
      rules.add(
        _matcherToRouteRule(
          rule.matcher,
          topology.outboundFor(rule.target, hopTags),
        ),
      );
    }

    return {
      'rules': rules,
      'final': topology.defaultOutbound,
      if (topology.findProcess) 'find_process': true,
      'auto_detect_interface': true,
      'default_domain_resolver': {
        'server': _defaultDomainResolver(tunnel, topology),
      },
    };
  }

  String _defaultDomainResolver(TunnelConfig tunnel, SingBoxTopology topology) {
    if (topology.nestedDefault) return SingBoxTags.bootstrapDns;
    if (topology.useTunResolveSniff && tunnel.dns.suffixRules.isEmpty) {
      return SingBoxTags.publicDns;
    }
    return SingBoxTags.bootstrapDns;
  }

  static final _dnsPinHijack = {
    'ip_cidr': ['${ConfigConstants.dnsPinIp}/32'],
    'port': [53],
    'action': 'hijack-dns',
  };

  List<Map<String, dynamic>> _splitCorpCidrRules({
    required TunnelConfig tunnel,
    required Map<String, String> hopTags,
  }) {
    if (!tunnel.routing.defaultTarget.isDirect) return const [];

    final rules = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final rule in tunnel.routing.sortedOverrides()) {
      if (rule.target.isDirect) continue;
      final chainId = rule.target.chainId;
      if (chainId == null || seen.contains(chainId)) continue;
      final outbound = hopTags[chainId];
      if (outbound == null) continue;
      seen.add(chainId);
      rules.add({
        'ip_cidr': List<String>.from(ConfigConstants.splitCorpCidrs),
        'outbound': outbound,
      });
    }

    return rules;
  }

  Map<String, dynamic> _matcherToRouteRule(
    RuleMatcher matcher,
    String outbound,
  ) {
    return switch (matcher.type) {
      MatcherType.ipCidr => {'ip_cidr': matcher.values, 'outbound': outbound},
      MatcherType.domainSuffix => {
        'domain_suffix': singBoxDomainSuffixes(matcher.values),
        'outbound': outbound,
      },
      MatcherType.port => {
        'port': matcher.values.map(int.parse).toList(),
        'outbound': outbound,
      },
      MatcherType.process => {
        'process_name': matcher.values,
        'outbound': outbound,
      },
      MatcherType.geoip => {'geoip': matcher.values, 'outbound': outbound},
    };
  }
}
