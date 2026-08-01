import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/services/system_dns_policy.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';

void main() {
  const corpDnsPrimary = '10.0.0.53';
  const corpDnsSecondary = '10.0.0.54';
  const publicDns = '1.1.1.1';

  final outer = VlessProfile(
    id: 'vless',
    name: 'VLESS',
    createdAt: DateTime(2026),
    host: '1.2.3.4',
    port: 443,
    uuidRef: const SecretRef('u'),
    security: 'tls',
  );

  final wg = WireGuardProfile(
    id: 'wg',
    name: 'WG',
    createdAt: DateTime(2026),
    addresses: ['10.0.0.2/32'],
    privateKeyRef: const SecretRef('k'),
    peerPublicKey: 'pk',
    endpointHost: '5.6.7.8',
    endpointPort: 51820,
    dnsServers: [corpDnsPrimary],
  );

  ConnectBundle bundle({
    required List<Chain> chains,
    required TunnelConfig tunnel,
  }) {
    return ConnectBundle(
      profiles: {'vless': outer, 'wg': wg},
      chains: chains,
      tunnel: tunnel,
    );
  }

  test('WG-only profile with corp DNS uses native system resolvers', () {
    const chainId = 'chain-wg';
    final b = bundle(
      chains: [
        const Chain(id: chainId, name: 'WG', hopProfileIds: ['wg']),
      ],
      tunnel: TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: const RouteTarget.chain(chainId),
        ),
        dns: DnsPolicy(
          publicResolver: '$corpDnsPrimary, $corpDnsSecondary',
        ),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isTrue);
    expect(
      SystemDnsPolicy.systemDnsServers(b),
      [corpDnsPrimary, corpDnsSecondary],
    );
  });

  test('single-chain nested profile (VLESS→WG) uses native corp DNS', () {
    const nestedId = 'chain-nested';
    final b = bundle(
      chains: [
        const Chain(
          id: nestedId,
          name: 'Nested',
          hopProfileIds: ['vless', 'wg'],
        ),
      ],
      tunnel: TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: const RouteTarget.chain(nestedId),
        ),
        dns: DnsPolicy(
          publicResolver: '$corpDnsPrimary, $corpDnsSecondary',
        ),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isTrue);
    expect(
      SystemDnsPolicy.systemDnsServers(b),
      [corpDnsPrimary, corpDnsSecondary],
    );
  });

  test('multi-chain split profile keeps DNS pin', () {
    const outdoorId = 'chain-vless';
    const workId = 'chain-wg';
    final b = bundle(
      chains: [
        const Chain(id: outdoorId, name: 'VLESS', hopProfileIds: ['vless']),
        const Chain(id: workId, name: 'WG', hopProfileIds: ['wg']),
      ],
      tunnel: TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: const RouteTarget.chain(outdoorId),
          overrides: [
            RoutingRule(
              order: 0,
              matcher: const RuleMatcher(
                type: MatcherType.ipCidr,
                values: ['10.0.0.0/8'],
              ),
              target: const RouteTarget.chain(workId),
            ),
          ],
        ),
        dns: const DnsPolicy(publicResolver: corpDnsPrimary),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isFalse);
    expect(
      SystemDnsPolicy.systemDnsServers(b),
      [ConfigConstants.dnsPinIp],
    );
  });

  test('pin address or no IPv4 resolvers keeps DNS pin', () {
    const chainId = 'chain-wg';
    final b = bundle(
      chains: [
        const Chain(id: chainId, name: 'WG', hopProfileIds: ['wg']),
      ],
      tunnel: const TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: RouteTarget.chain(chainId),
        ),
        dns: DnsPolicy(publicResolver: ConfigConstants.dnsPinIp),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isFalse);
    expect(
      SystemDnsPolicy.systemDnsServers(b),
      [ConfigConstants.dnsPinIp],
    );
  });

  test('domain suffix split routing keeps DNS pin', () {
    const chainId = 'chain-wg';
    final b = bundle(
      chains: [
        const Chain(id: chainId, name: 'WG', hopProfileIds: ['wg']),
      ],
      tunnel: TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: const RouteTarget.direct(),
          overrides: [
            RoutingRule(
              order: 0,
              matcher: const RuleMatcher(
                type: MatcherType.domainSuffix,
                values: ['corp.internal'],
              ),
              target: const RouteTarget.chain(chainId),
            ),
          ],
        ),
        dns: const DnsPolicy(publicResolver: corpDnsPrimary),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isFalse);
  });

  test('VLESS-only outdoor profile uses native 1.1.1.1', () {
    const chainId = 'chain-vless';
    final b = bundle(
      chains: [
        const Chain(id: chainId, name: 'VLESS', hopProfileIds: ['vless']),
      ],
      tunnel: const TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: RouteTarget.chain(chainId),
        ),
        dns: DnsPolicy(publicResolver: publicDns),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isTrue);
    expect(SystemDnsPolicy.systemDnsServers(b), [publicDns]);
  });

  test('custom dns upstreams keep DNS pin', () {
    const chainId = 'chain-wg';
    final b = bundle(
      chains: [
        const Chain(id: chainId, name: 'WG', hopProfileIds: ['wg']),
      ],
      tunnel: TunnelConfig(
        routing: RoutingPolicy(
          defaultTarget: const RouteTarget.chain(chainId),
        ),
        dns: const DnsPolicy(
          publicResolver: corpDnsPrimary,
          upstreams: [
            DnsUpstream(
              tag: 'dns-corp',
              server: '10.0.0.53',
              viaChainId: chainId,
            ),
          ],
        ),
        clashApiSecret: 'x',
      ),
    );

    expect(SystemDnsPolicy.usesNativeSystemDns(b), isFalse);
  });
}
