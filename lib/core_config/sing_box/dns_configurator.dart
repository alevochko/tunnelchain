import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/core_config/sing_box/chain_assembler.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_topology.dart';
import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';

/// Builds the `dns` section; layout follows [SingBoxTopology] variant.
class SingBoxDnsConfigurator {
  Map<String, dynamic> build({
    required TunnelConfig tunnel,
    required SingBoxTopology topology,
    required ChainAssembly chains,
  }) {
    final servers = _buildServers(
      tunnel: tunnel,
      topology: topology,
      chains: chains,
    );

    return _finalize(
      servers: servers,
      dns: tunnel.dns,
      finalTag: _finalTag(topology, tunnel),
      strategy: _strategy(topology),
    );
  }

  String _finalTag(SingBoxTopology topology, TunnelConfig tunnel) {
    if (topology.wgOnlyDefault ||
        topology.vlessOnlyDefault ||
        topology.nestedDefault) {
      return SingBoxTags.publicDns;
    }
    return tunnel.dns.defaultUpstreamTag;
  }

  String _strategy(SingBoxTopology topology) {
    if (topology.wgOnlyDefault ||
        topology.vlessOnlyDefault ||
        topology.nestedDefault) {
      return 'prefer_ipv4';
    }
    return 'ipv4_only';
  }

  List<Map<String, dynamic>> _buildServers({
    required TunnelConfig tunnel,
    required SingBoxTopology topology,
    required ChainAssembly chains,
  }) {
    if (topology.wgOnlyDefault) {
      return [
        _bootstrap(),
        ..._publicResolvers(
          resolvers: tunnel.dns.resolverList,
          type: 'udp',
          detour: topology.defaultOutbound,
        ),
        ..._corpUpstreams(tunnel.dns, chains.hopTags),
      ];
    }

    if (topology.vlessOnlyDefault) {
      return [
        _bootstrap(),
        ..._publicResolvers(
          resolvers: tunnel.dns.resolverList,
          type: 'udp',
          detour: topology.defaultOutbound,
        ),
        ..._corpUpstreams(tunnel.dns, chains.hopTags),
      ];
    }

    if (topology.nestedDefault && topology.defaultChain != null) {
      final hops = chains.chainHopTags[topology.defaultChain!.id] ?? [];
      final outerHop = hops.isNotEmpty ? hops.first : topology.defaultOutbound;
      final innerHop = hops.isNotEmpty ? hops.last : topology.defaultOutbound;

      return [
        _bootstrap(),
        ..._publicResolvers(
          resolvers: tunnel.dns.resolverList,
          type: 'udp',
          detour: innerHop,
        ),
        ..._publicResolvers(
          resolvers: tunnel.dns.resolverList,
          type: 'udp',
          detour: outerHop,
          tagPrefix: SingBoxTags.outerHopDns(topology.defaultChain!.id),
        ),
        ..._corpUpstreams(tunnel.dns, chains.hopTags),
      ];
    }

    // Split / default-direct: DoH avoids macOS TUN capturing upstream UDP/53.
    final publicDetour = topology.defaultOutbound == SingBoxTags.direct
        ? null
        : topology.defaultOutbound;

    final servers = <Map<String, dynamic>>[
      _bootstrap(),
      ..._publicResolvers(
        resolvers: tunnel.dns.resolverList,
        type: 'https',
        detour: publicDetour,
      ),
    ];

    for (final chainId in topology.referencedChainIds) {
      final hops = chains.chainHopTags[chainId] ?? [];
      if (hops.length >= 2) {
        servers.addAll(
          _publicResolvers(
            resolvers: tunnel.dns.resolverList,
            type: 'https',
            detour: hops.first,
            tagPrefix: SingBoxTags.outerHopDns(chainId),
          ),
        );
      }
    }

    servers.addAll(_corpUpstreams(tunnel.dns, chains.hopTags));
    return servers;
  }

  Map<String, dynamic> _bootstrap() => {
    'type': 'local',
    'tag': SingBoxTags.bootstrapDns,
  };

  List<Map<String, dynamic>> _corpUpstreams(
    DnsPolicy dns,
    Map<String, String> hopTags,
  ) => [for (final u in dns.upstreams) _upstreamToServer(u, hopTags)];

  List<Map<String, dynamic>> _publicResolvers({
    required List<String> resolvers,
    required String type,
    String? detour,
    String tagPrefix = SingBoxTags.publicDns,
  }) {
    final list = resolvers.isEmpty ? ['1.1.1.1'] : resolvers;
    return [
      for (var i = 0; i < list.length; i++)
        {
          'type': type,
          'tag': i == 0 ? tagPrefix : '$tagPrefix-${i + 1}',
          'server': list[i],
          if (type == 'udp') 'server_port': 53,
          if (detour != null && detour != SingBoxTags.direct) 'detour': detour,
        },
    ];
  }

  Map<String, dynamic> _upstreamToServer(
    DnsUpstream upstream,
    Map<String, String> hopTags,
  ) {
    final server = <String, dynamic>{
      'tag': upstream.tag,
      'server': upstream.server,
    };

    switch (upstream.transport) {
      case DnsTransport.https:
        server['type'] = 'https';
      case DnsTransport.udp:
        server['type'] = 'udp';
        server['server_port'] = 53;
      case DnsTransport.local:
        server['type'] = 'local';
        server.remove('server');
    }

    if (upstream.viaChainId != null) {
      final detour = hopTags[upstream.viaChainId];
      if (detour == null) {
        throw StateError(
          'DNS upstream "${upstream.tag}" references unknown chain '
          '"${upstream.viaChainId}"',
        );
      }
      server['detour'] = detour;
    }

    return server;
  }

  Map<String, dynamic> _finalize({
    required List<Map<String, dynamic>> servers,
    required DnsPolicy dns,
    required String finalTag,
    required String strategy,
  }) {
    final rules = <Map<String, dynamic>>[];
    for (final rule in dns.suffixRules) {
      rules.add({
        'domain_suffix': singBoxDomainSuffixes(rule.suffixes),
        'server': rule.upstreamTag,
      });
    }

    if (dns.includeReverseZones &&
        dns.suffixRules.isNotEmpty &&
        dns.upstreams.isNotEmpty) {
      rules.add({
        'domain_suffix': ['.in-addr.arpa'],
        'server': dns.upstreams.first.tag,
      });
    }

    return {
      'servers': servers,
      if (rules.isNotEmpty) 'rules': rules,
      'final': finalTag,
      'strategy': strategy,
    };
  }
}
