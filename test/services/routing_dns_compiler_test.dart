import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/core_config/config_generator.dart';
import 'package:tunnel_chain/core_config/config_invariants.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/rule_dns.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
import 'package:tunnel_chain/services/routing_dns_compiler.dart';

void main() {
  test('compiles per-rule DNS into suffix rules and upstreams', () {
    const workChain = 'chain-work';
    const routing = RoutingPolicy(
      defaultTarget: RouteTarget.direct(),
      overrides: [
        RoutingRule(
          order: 0,
          matcher: RuleMatcher(
            type: MatcherType.domainSuffix,
            values: ['.corp.local'],
          ),
          target: RouteTarget.chain(workChain),
          dns: RuleDns(server: '10.0.0.53'),
        ),
      ],
    );

    final compiled = RoutingDnsCompiler.compile(
      base: const DnsPolicy(publicResolver: '1.1.1.1'),
      routing: routing,
    );

    expect(compiled.upstreams, hasLength(1));
    expect(compiled.upstreams.first.tag, 'dns-rule-0');
    expect(compiled.upstreams.first.server, '10.0.0.53');
    expect(compiled.upstreams.first.viaChainId, workChain);
    expect(compiled.suffixRules, hasLength(1));
    expect(compiled.suffixRules.first.suffixes, ['.corp.local']);
  });

  test('auto-adds wireguard dns for domain rules without explicit rule dns', () {
    const workChain = 'chain-work';
    const wgId = 'wg-node';
    final wg = WireGuardProfile(
      id: wgId,
      name: 'Work',
      createdAt: DateTime(2026),
      addresses: const ['10.0.0.2/32'],
      privateKeyRef: const SecretRef('wg.priv'),
      peerPublicKey: 'pk',
      endpointHost: '1.2.3.4',
      endpointPort: 51820,
      dnsServers: const ['10.0.0.53'],
    );
    const routing = RoutingPolicy(
      defaultTarget: RouteTarget.direct(),
      overrides: [
        RoutingRule(
          order: 0,
          matcher: RuleMatcher(
            type: MatcherType.domainSuffix,
            values: ['.corp.internal'],
          ),
          target: RouteTarget.chain(workChain),
        ),
      ],
    );

    final compiled = RoutingDnsCompiler.compile(
      base: const DnsPolicy(publicResolver: '1.1.1.1'),
      routing: routing,
      chains: const [
        Chain(id: workChain, name: 'Work', hopProfileIds: [wgId]),
      ],
      profiles: {wgId: wg},
    );

    expect(compiled.upstreams, hasLength(1));
    expect(compiled.upstreams.first.server, '10.0.0.53');
    expect(compiled.upstreams.first.viaChainId, workChain);
    expect(compiled.suffixRules.first.upstreamTag, 'dns-rule-0');
  });

  test('split routing emits per-rule DNS in sing-box config', () {
    const workChain = 'chain-work';
    const vlessChain = 'chain-vless';
    final routing = RoutingPolicy(
      defaultTarget: const RouteTarget.direct(),
      overrides: [
        const RoutingRule(
          order: 0,
          matcher: RuleMatcher(
            type: MatcherType.domainSuffix,
            values: ['.corp.local'],
          ),
          target: RouteTarget.chain(workChain),
          dns: RuleDns(server: '10.0.0.53'),
        ),
      ],
    );

    final dns = RoutingDnsCompiler.compile(
      base: const DnsPolicy(publicResolver: '1.1.1.1'),
      routing: routing,
    );

    final config = ConfigGenerator().generate(
      profiles: SampleTunnel.profiles,
      chains: [
        Chain(
          id: workChain,
          name: 'Work',
          hopProfileIds: [SampleTunnel.innerProfile.id],
        ),
        Chain(
          id: vlessChain,
          name: 'VLESS',
          hopProfileIds: [SampleTunnel.outerProfile.id],
        ),
      ],
      tunnel: TunnelConfig(
        routing: routing,
        dns: dns,
        clashApiSecret: 'x',
      ),
      secrets: SampleTunnel.secrets,
    );

    final dnsServers = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      dnsServers.any((s) => s['tag'] == 'dns-rule-0'),
      isTrue,
    );
    final workDns = dnsServers.firstWhere((s) => s['tag'] == 'dns-rule-0');
    expect(workDns['server'], '10.0.0.53');
    expect(workDns['detour'], 'chain-work-hop0');

    final dnsRules = (config['dns']['rules'] as List).cast<Map>();
    expect(
      dnsRules.any(
        (r) =>
            (r['domain_suffix'] as List).contains('corp.local') &&
            r['server'] == 'dns-rule-0',
      ),
      isTrue,
    );
    expect(config['dns']['final'], 'dns-public');
    ConfigInvariants.assertAll(config);
  });
}
