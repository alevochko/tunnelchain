import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/core_config/config_generator.dart';
import 'package:tunnel_chain/core_config/config_invariants.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';

import 'nested_chain_fixture.dart';

void main() {
  test('single-hop vless chain uses launcher tun template', () {
    const chainId = 'chain-vless';
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain(chainId),
      ),
      dns: const DnsPolicy(),
      tunMtu: 1492,
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: SampleTunnel.profiles,
      chains: [
        Chain(
          id: chainId,
          name: 'VLESS',
          hopProfileIds: [SampleTunnel.outerProfile.id],
        ),
      ],
      tunnel: tunnel,
      secrets: SampleTunnel.secrets,
    );

    expect(config.containsKey('endpoints'), isFalse);
    expect(config['route']['final'], 'chain-vless-hop0');
    expect(config['route'].containsKey('find_process'), isFalse);
    final rules = config['route']['rules'] as List;
    expect((rules.first as Map)['action'], 'hijack-dns');
    expect(rules[1]['action'], 'resolve');
    expect(rules[2]['action'], 'sniff');
    expect(rules[3]['action'], 'hijack-dns');
    final tun = (config['inbounds'] as List).first as Map;
    expect(tun['stack'], 'system');
    expect(tun['strict_route'], isTrue);
    expect(tun.containsKey('route_exclude_address'), isFalse);
    final dnsPublic = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public');
    expect(dnsPublic['type'], 'udp');
    expect(dnsPublic['detour'], 'chain-vless-hop0');
    expect(dnsPublic['server'], '1.1.1.1');
    expect(config['dns']['final'], 'dns-public');
    ConfigInvariants.assertAll(config);
  });

  test('comma-separated public resolver uses first address in sing-box config', () {
    const chainId = 'chain-vless';
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain(chainId),
      ),
      dns: const DnsPolicy(publicResolver: '1.1.1.1,8.8.8.8'),
      tunMtu: 1492,
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: SampleTunnel.profiles,
      chains: [
        Chain(
          id: chainId,
          name: 'VLESS',
          hopProfileIds: [SampleTunnel.outerProfile.id],
        ),
      ],
      tunnel: tunnel,
      secrets: SampleTunnel.secrets,
    );

    final dnsPublic = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public');
    expect(dnsPublic['server'], '1.1.1.1');

    final dnsAlt = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public-2');
    expect(dnsAlt['server'], '8.8.8.8');
    ConfigInvariants.assertAll(config);
  });

  test('split domain routing to wg chain sets non-empty allowed_ips', () {
    const workChainId = 'chain-work-wg';
    final inner = SampleTunnel.innerProfile;
    final wgProfile = WireGuardProfile(
      id: inner.id,
      name: inner.name,
      createdAt: inner.createdAt,
      addresses: inner.addresses,
      privateKeyRef: inner.privateKeyRef,
      peerPublicKey: inner.peerPublicKey,
      presharedKeyRef: inner.presharedKeyRef,
      endpointHost: inner.endpointHost,
      endpointPort: inner.endpointPort,
      dnsServers: inner.dnsServers,
      mtu: inner.mtu,
      allowedIps: const [],
    );
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.direct(),
        overrides: [
          const RoutingRule(
            order: 0,
            matcher: RuleMatcher(
              type: MatcherType.domainSuffix,
              values: ['.corp.local'],
            ),
            target: RouteTarget.chain(workChainId),
          ),
        ],
      ),
      dns: const DnsPolicy(),
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: {
        ...SampleTunnel.profiles,
        wgProfile.id: wgProfile,
      },
      chains: [
        Chain(
          id: workChainId,
          name: 'Work',
          hopProfileIds: [wgProfile.id],
        ),
      ],
      tunnel: tunnel,
      secrets: SampleTunnel.secrets,
    );

    final peers = ((config['endpoints'] as List).first
        as Map<String, dynamic>)['peers'] as List;
    expect((peers.first as Map)['allowed_ips'], [
      '10.0.0.0/8',
      '10.0.0.53/32',
      '172.20.0.0/16',
    ]);
    expect(config['route']['final'], 'direct');

    final routeRules = (config['route']['rules'] as List).cast<Map>();
    expect(
      routeRules.any(
        (r) => r['inbound'] == 'tun-in' && r['action'] == 'resolve',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (r) => r['inbound'] == 'tun-in' && r['action'] == 'sniff',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (r) =>
            r['ip_cidr'] is List &&
            (r['ip_cidr'] as List).contains('10.0.0.0/8') &&
            r['outbound'] == 'chain-work-wg-hop0',
      ),
      isTrue,
    );
    expect(
      routeRules.any(
        (r) =>
            r['domain_suffix'] is List &&
            (r['domain_suffix'] as List).contains('corp.local') &&
            r['outbound'] == 'chain-work-wg-hop0',
      ),
      isTrue,
    );

    final dnsPublic = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public');
    expect(dnsPublic['type'], 'https');
    expect(dnsPublic.containsKey('detour'), isFalse);

    final tun = (config['inbounds'] as List).first as Map;
    expect(tun['strict_route'], isFalse);
    final endpoint = (config['endpoints'] as List).first as Map;
    expect(endpoint['system'], isFalse);
    expect(endpoint.containsKey('detour'), isFalse);
    expect(endpoint['domain_resolver'], 'dns-bootstrap');
    expect(
      routeRules.any(
        (r) => r['ip_is_private'] == true && r['outbound'] == 'direct',
      ),
      isTrue,
    );
    ConfigInvariants.assertAll(config);
  });

  test('single-hop chain: only outbounds, no endpoints', () {
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain('chain-outer'),
      ),
      dns: const DnsPolicy(),
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: NestedChainFixture.profiles,
      chains: [NestedChainFixture.chains.first],
      tunnel: tunnel,
      secrets: NestedChainFixture.secrets,
    );

    expect(config.containsKey('endpoints'), isFalse);
    expect(config['route']['final'], 'chain-outer-hop0');
    ConfigInvariants.assertAll(config);
  });

  test('single-hop wireguard chain matches singbox-launcher template', () {
    const chainId = 'chain-wg';
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain(chainId),
      ),
      dns: const DnsPolicy(),
      tunMtu: 1492,
      wgMtu: SampleTunnel.innerProfile.mtu,
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: SampleTunnel.profiles,
      chains: [
        Chain(
          id: chainId,
          name: 'Work',
          hopProfileIds: [SampleTunnel.innerProfile.id],
        ),
      ],
      tunnel: tunnel,
      secrets: SampleTunnel.secrets,
    );

    final endpoints = config['endpoints'] as List<dynamic>;
    expect(endpoints, hasLength(1));
    final endpoint = endpoints.first as Map<String, dynamic>;
    expect(endpoint['tag'], 'chain-wg-hop0');
    expect(endpoint.containsKey('detour'), isFalse);
    expect(endpoint.containsKey('domain_resolver'), isFalse);
    expect(endpoint['system'], isFalse);
    expect(config['route']['final'], 'chain-wg-hop0');
    final rules = config['route']['rules'] as List;
    expect(rules, hasLength(4));
    expect((rules.first as Map)['action'], 'hijack-dns');
    expect(rules[1]['action'], 'resolve');
    expect(rules[2]['action'], 'sniff');
    expect(rules[3]['action'], 'hijack-dns');
    final tun = (config['inbounds'] as List).first as Map;
    expect(tun['stack'], 'system');
    expect(tun['strict_route'], isFalse);
    expect(tun.containsKey('route_exclude_address'), isFalse);
    expect(tun['mtu'], 1492);
    expect(endpoint['mtu'], SampleTunnel.innerProfile.mtu);
    final peers = endpoint['peers'] as List;
    expect(peers.first['allowed_ips'], ['0.0.0.0/0', '::/0']);
    expect(config['dns']['final'], 'dns-public');
    final dnsPublic = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public');
    expect(dnsPublic['type'], 'udp');
    expect(dnsPublic['detour'], 'chain-wg-hop0');
    ConfigInvariants.assertAll(config);
  });

  test('nested chain fixture: hop tags and explicit DNS upstreams', () {
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain('chain-nested'),
        overrides: SampleTunnel.tunnelConfig.routing.overrides,
      ),
      dns: SampleTunnel.tunnelConfig.dns,
      tunMtu: 1280,
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: NestedChainFixture.profiles,
      chains: NestedChainFixture.chains,
      tunnel: tunnel,
      secrets: NestedChainFixture.secrets,
    );

    expect(config['route']['final'], 'chain-nested-hop1');
    final rules = config['route']['rules'] as List;
    expect((rules.first as Map)['action'], 'hijack-dns');
    expect(rules[1]['action'], 'resolve');
    expect(rules[2]['action'], 'sniff');
    expect(rules[3]['action'], 'hijack-dns');
    final tun = (config['inbounds'] as List).first as Map;
    expect(tun['stack'], 'system');
    expect(tun['strict_route'], isTrue);
    expect(tun.containsKey('route_exclude_address'), isFalse);
    final endpoints = config['endpoints'] as List<dynamic>;
    expect(endpoints, hasLength(1));
    expect(endpoints.first['tag'], 'chain-nested-hop1');
    expect(endpoints.first['detour'], 'chain-nested-hop0');
    expect(endpoints.first['domain_resolver'], 'dns-via-chain-nested');
    expect(endpoints.first['mtu'], 1280);

    final dnsServers = (config['dns']['servers'] as List)
        .map((s) => (s as Map)['tag'])
        .toList();
    expect(dnsServers, contains('dns-internal'));
    expect(dnsServers, contains('dns-via-chain-nested'));
    final viaVless = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-via-chain-nested');
    expect(viaVless['type'], 'udp');
    expect(viaVless['detour'], 'chain-nested-hop0');
    final dnsPublic = (config['dns']['servers'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['tag'] == 'dns-public');
    expect(dnsPublic['type'], 'udp');
    expect(dnsPublic['detour'], 'chain-nested-hop1');
    expect(config['dns']['final'], 'dns-public');
    expect(
      config['route']['default_domain_resolver']['server'],
      'dns-bootstrap',
    );

    ConfigInvariants.assertAll(config);
  });

  test('default nested chain uses 0.0.0.0/0 allowed_ips', () {
    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain('chain-nested'),
      ),
      dns: const DnsPolicy(),
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: NestedChainFixture.profiles,
      chains: NestedChainFixture.chains,
      tunnel: tunnel,
      secrets: NestedChainFixture.secrets,
    );

    final peers =
        (config['endpoints'] as List).first['peers'] as List<dynamic>;
    expect(peers.first['allowed_ips'], ['0.0.0.0/0', '::/0']);
  });

  test('generated config passes sing-box check', () async {
    final singBox = await _findSingBox();
    if (singBox == null) {
      // ignore: avoid_print
      print('sing-box not found — skipping integration check');
      return;
    }

    final config = NestedChainFixture.generate();
    final file = File(
      '${Directory.systemTemp.path}/tunnelchain-test-config.json',
    );
    await file.writeAsString(jsonEncode(config));

    final result = await Process.run(singBox, ['check', '-c', file.path]);
    expect(
      result.exitCode,
      0,
      reason: 'sing-box check failed:\n${result.stderr}\n${result.stdout}',
    );
  });
}

Future<String?> _findSingBox() async {
  for (final path in [
    '/usr/local/bin/sing-box',
    '/opt/homebrew/bin/sing-box',
  ]) {
    if (await File(path).exists()) return path;
  }
  final which = await Process.run('which', ['sing-box']);
  if (which.exitCode == 0) return (which.stdout as String).trim();
  return null;
}
