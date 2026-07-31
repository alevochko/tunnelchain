import 'dart:convert';

import 'package:tunnel_chain/core_config/config_generator.dart';
import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Built-in sample topology for demos and tests (synthetic endpoints only).
class SampleTunnel {
  static final createdAt = DateTime(2026, 1, 1);

  static final outerProfile = VlessProfile(
    id: 'profile-outer',
    name: 'Outer hop',
    createdAt: createdAt,
    host: '203.0.113.10',
    port: 443,
    uuidRef: const SecretRef('secret.outer.uuid'),
    security: 'reality',
    sni: 'cdn.example.com',
    publicKeyRef: const SecretRef('secret.outer.pbk'),
    shortId: '01020304',
    fingerprint: 'chrome',
    flow: 'xtls-rprx-vision',
  );

  static final innerProfile = WireGuardProfile(
    id: 'profile-inner',
    name: 'Inner hop',
    createdAt: createdAt,
    addresses: ['10.0.0.2/32'],
    privateKeyRef: const SecretRef('secret.inner.priv'),
    peerPublicKey: 'DOqrZQ6+bYiq3Dr8qJ2yFYMDS1Y2zevVBqIifmz8niU=',
    presharedKeyRef: const SecretRef('secret.inner.psk'),
    endpointHost: '198.51.100.20',
    endpointPort: 51820,
    dnsServers: ['10.0.0.53'],
    searchDomains: ['internal.example', 'private.example'],
    allowedIps: ['10.0.0.0/8', '172.20.0.0/16'],
  );

  static Map<String, Profile> get profiles => {
    'profile-outer': outerProfile,
    'profile-inner': innerProfile,
  };

  static List<Chain> get chains => [
    const Chain(
      id: 'chain-outer',
      name: 'Single outer',
      hopProfileIds: ['profile-outer'],
    ),
    const Chain(
      id: 'chain-nested',
      name: 'Nested',
      hopProfileIds: ['profile-outer', 'profile-inner'],
    ),
  ];

  static TunnelConfig get tunnelConfig => TunnelConfig(
    routing: RoutingPolicy(
      defaultTarget: const RouteTarget.chain('chain-outer'),
      overrides: [
        RoutingRule(
          order: 0,
          matcher: const RuleMatcher(
            type: MatcherType.ipCidr,
            values: ['192.168.1.0/24'],
          ),
          target: const RouteTarget.direct(),
        ),
        RoutingRule(
          order: 1,
          matcher: const RuleMatcher(
            type: MatcherType.ipCidr,
            values: ['10.0.0.0/8', '172.20.0.0/16'],
          ),
          target: const RouteTarget.chain('chain-nested'),
        ),
        RoutingRule(
          order: 2,
          matcher: const RuleMatcher(
            type: MatcherType.domainSuffix,
            values: ['internal.example', 'private.example'],
          ),
          target: const RouteTarget.chain('chain-nested'),
        ),
      ],
    ),
    dns: DnsPolicy(
      suffixRules: const [
        DnsSuffixRule(
          suffixes: ['internal.example', 'private.example'],
          upstreamTag: 'dns-internal',
        ),
      ],
      upstreams: const [
        DnsUpstream(
          tag: 'dns-internal',
          server: '10.0.0.53',
          transport: DnsTransport.udp,
          viaChainId: 'chain-nested',
        ),
      ],
      includeReverseZones: true,
      searchDomains: ['internal.example', 'private.example'],
    ),
    clashApiSecret: 'tunnelchain-dev-secret',
  );

  static final secrets = MapSecretResolver({
    'secret.outer.uuid': '550e8400-e29b-41d4-a716-446655440000',
    'secret.outer.pbk': 'spOJjek2S_Zkx2eDVA7r57OqpqmcU8_tdVzXW0-vJ0I',
    'secret.inner.priv': 'EOneqFYge/y/jHeEMNRjptzUUR5YeQrHVSt81CpZ0Eg=',
    'secret.inner.psk': '8DbDwZN+tJoLkjF77gGbBBO8xxLrqDfPWwvuWLLCaE8=',
  });

  static Map<String, dynamic> generateConfig() {
    return ConfigGenerator().generate(
      profiles: profiles,
      chains: chains,
      tunnel: tunnelConfig,
      secrets: secrets,
    );
  }

  static String generateConfigJson() {
    return const JsonEncoder.withIndent('  ').convert(generateConfig());
  }

  /// Alias for tests that called [generate] on the old fixture name.
  static Map<String, dynamic> generate() => generateConfig();

  static String? defaultChainName() {
    final id = tunnelConfig.routing.defaultTarget.chainId;
    if (id == null) return null;
    return chains.firstWhere((c) => c.id == id, orElse: () => chains.first).name;
  }

  static List<String> layerLabels() {
    final defaultId = tunnelConfig.routing.defaultTarget.chainId;
    final chain = chains.firstWhere(
      (c) => c.id == defaultId,
      orElse: () => chains.first,
    );
    final labels = <String>['Application'];
    for (final hopId in chain.hopProfileIds.reversed) {
      final profile = profiles[hopId];
      labels.add(profile?.name ?? hopId);
    }
    labels.add('Egress');
    return labels;
  }
}
