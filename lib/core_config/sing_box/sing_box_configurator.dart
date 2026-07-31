import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/core_config/sing_box/chain_assembler.dart';
import 'package:tunnel_chain/core_config/sing_box/dns_configurator.dart';
import 'package:tunnel_chain/core_config/sing_box/route_configurator.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/core_config/connect_topology.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_topology.dart';
import 'package:tunnel_chain/core_config/sing_box/tun_configurator.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/validators/chain_validator.dart';
import 'package:tunnel_chain/domain/validators/routing_validator.dart';

/// Orchestrates sing-box JSON generation from domain models (AR §5).
///
/// Algorithm:
/// 1. Validate routing and referenced chains.
/// 2. [ChainAssembler] — outbounds + wireguard endpoints.
/// 3. [SingBoxTopology] — derived layout flags from routing.
/// 4. Section configurators — dns, inbounds, route.
class SingBoxConfigurator {
  SingBoxConfigurator({
    ChainValidator? chainValidator,
    RoutingValidator? routingValidator,
    ChainAssembler? chainAssembler,
    SingBoxDnsConfigurator? dnsConfigurator,
    SingBoxTunConfigurator? tunConfigurator,
    SingBoxRouteConfigurator? routeConfigurator,
  }) : _chainValidator = chainValidator ?? ChainValidator(),
       _routingValidator = routingValidator ?? RoutingValidator(),
       _chainAssembler = chainAssembler ?? ChainAssembler(),
       _dns = dnsConfigurator ?? SingBoxDnsConfigurator(),
       _tun = tunConfigurator ?? SingBoxTunConfigurator(),
       _route = routeConfigurator ?? SingBoxRouteConfigurator();

  final ChainValidator _chainValidator;
  final RoutingValidator _routingValidator;
  final ChainAssembler _chainAssembler;
  final SingBoxDnsConfigurator _dns;
  final SingBoxTunConfigurator _tun;
  final SingBoxRouteConfigurator _route;

  Map<String, dynamic> build({
    required Map<String, Profile> profiles,
    required List<Chain> chains,
    required TunnelConfig tunnel,
    required SecretResolver secrets,
  }) {
    final chainById = {for (final c in chains) c.id: c};
    final referenced = tunnel.referencedChainIds();
    _routingValidator.validate(tunnel.routing, chainById.keys.toSet());

    for (final chainId in referenced) {
      final chain = chainById[chainId];
      if (chain == null) {
        throw StateError('Referenced chain "$chainId" not found');
      }
      _chainValidator.validate(chain, profiles);
    }

    final wgOnlyDefault = isNativeWireGuardDefault(
      routing: tunnel.routing,
      chains: chains,
      profiles: profiles,
    );

    final chainsBuilt = _chainAssembler.assemble(
      referencedChainIds: referenced,
      chainById: chainById,
      profiles: profiles,
      tunnel: tunnel,
      wgOnlyDefault: wgOnlyDefault,
      secrets: secrets,
    );

    final topology = SingBoxTopology.compute(
      routing: tunnel.routing,
      chains: chains,
      profiles: profiles,
      hopTags: chainsBuilt.hopTags,
      referenced: referenced,
    );

    return {
      'log': {'level': 'info', 'timestamp': true},
      'dns': _dns.build(
        tunnel: tunnel,
        topology: topology,
        chains: chainsBuilt,
      ),
      if (chainsBuilt.endpoints.isNotEmpty) 'endpoints': chainsBuilt.endpoints,
      'inbounds': [_tun.build(tunnel: tunnel, topology: topology)],
      'outbounds': [
        ...chainsBuilt.outbounds,
        {'type': 'direct', 'tag': SingBoxTags.direct},
      ],
      'route': _route.build(
        tunnel: tunnel,
        topology: topology,
        hopTags: chainsBuilt.hopTags,
      ),
      'experimental': {
        'clash_api': {
          'external_controller': ConfigConstants.clashApiHost,
          'secret': tunnel.clashApiSecret ?? 'tunnelchain-dev-secret',
        },
      },
    };
  }
}
