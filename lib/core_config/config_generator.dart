import 'dart:convert';

import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_configurator.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/validators/chain_validator.dart';
import 'package:tunnel_chain/domain/validators/routing_validator.dart';

/// Facade over [SingBoxConfigurator] — keeps the public API stable.
class ConfigGenerator {
  ConfigGenerator({
    ChainValidator? chainValidator,
    RoutingValidator? routingValidator,
    SingBoxConfigurator? configurator,
  }) : _configurator =
           configurator ??
           SingBoxConfigurator(
             chainValidator: chainValidator,
             routingValidator: routingValidator,
           );

  final SingBoxConfigurator _configurator;

  static String hopTag(String chainId, int index) => SingBoxTags.hop(chainId, index);

  /// DNS resolver through the outer hop of [chainId] (for inner-hop endpoint lookup).
  static String outerHopDnsTag(String chainId) => SingBoxTags.outerHopDns(chainId);

  Map<String, dynamic> generate({
    required Map<String, Profile> profiles,
    required List<Chain> chains,
    required TunnelConfig tunnel,
    required SecretResolver secrets,
  }) =>
      _configurator.build(
        profiles: profiles,
        chains: chains,
        tunnel: tunnel,
        secrets: secrets,
      );

  String toJson({
    required Map<String, Profile> profiles,
    required List<Chain> chains,
    required TunnelConfig tunnel,
    required SecretResolver secrets,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      generate(
        profiles: profiles,
        chains: chains,
        tunnel: tunnel,
        secrets: secrets,
      ),
    );
  }
}
