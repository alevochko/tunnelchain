import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/services/routing_dns_compiler.dart';

/// User-defined profile: routing + DNS. Chains are referenced by route targets.
class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.routing,
    this.dns = const DnsPolicy(),
  });

  final String id;
  final String name;
  final RoutingPolicy routing;
  final DnsPolicy dns;

  /// All chain ids referenced by default route and override rules.
  Set<String> referencedChainIds() => routing.referencedChainIds();

  /// Standalone VPN: everything goes through one chain, no split rules.
  bool get isSimpleFullTunnel =>
      routing.overrides.isEmpty && !routing.defaultTarget.isDirect;

  String? get simpleChainId =>
      isSimpleFullTunnel ? routing.defaultTarget.chainId : null;

  /// Profile DNS merged with per-rule resolver overrides.
  DnsPolicy compiledDns({
    List<Chain> chains = const [],
    Map<String, Profile> profiles = const {},
  }) =>
      RoutingDnsCompiler.compile(
        base: dns,
        routing: routing,
        chains: chains,
        profiles: profiles,
      );

  ConnectionProfile copyWith({
    String? id,
    String? name,
    RoutingPolicy? routing,
    DnsPolicy? dns,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      routing: routing ?? this.routing,
      dns: dns ?? this.dns,
    );
  }
}
