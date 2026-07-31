/// How DNS queries reach a resolver (sing-box server `type`).
enum DnsTransport {
  https,
  udp,
  local,
}

/// A named DNS upstream. Traffic to the resolver goes through [viaChainId] when set.
class DnsUpstream {
  const DnsUpstream({
    required this.tag,
    required this.server,
    this.transport = DnsTransport.https,
    this.viaChainId,
  });

  /// sing-box DNS server tag (referenced by rules and domain_resolver).
  final String tag;

  /// Resolver address (ignored for [DnsTransport.local]).
  final String server;

  final DnsTransport transport;

  /// Chain whose **last hop** is used as `detour` to reach this resolver.
  /// `null` — bootstrap / direct (local resolver only).
  final String? viaChainId;
}

/// Maps domain suffixes to a DNS upstream tag.
class DnsSuffixRule {
  const DnsSuffixRule({
    required this.suffixes,
    required this.upstreamTag,
  });

  final List<String> suffixes;
  final String upstreamTag;
}
