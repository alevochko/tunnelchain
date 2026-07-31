import 'package:tunnel_chain/domain/models/dns_upstream.dart';

/// DNS resolver for domains matched by a routing rule.
///
/// When [viaChain] is true and the rule targets a chain, queries reach
/// [server] through that chain (typical for internal corp DNS).
class RuleDns {
  const RuleDns({
    required this.server,
    this.transport = DnsTransport.udp,
    this.viaChain = true,
  });

  final String server;
  final DnsTransport transport;

  /// Route DNS queries to [server] through the rule's chain outbound.
  final bool viaChain;

  RuleDns copyWith({
    String? server,
    DnsTransport? transport,
    bool? viaChain,
  }) {
    return RuleDns(
      server: server ?? this.server,
      transport: transport ?? this.transport,
      viaChain: viaChain ?? this.viaChain,
    );
  }
}
