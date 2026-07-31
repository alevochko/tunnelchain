import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';

/// DNS policy — protocol- and scenario-agnostic.
///
/// The generator always adds bootstrap + public resolvers (AR §5.3).
/// Additional upstreams and suffix rules are declared explicitly.
class DnsPolicy {
  const DnsPolicy({
    this.publicResolver = '1.1.1.1',
    this.upstreams = const [],
    this.suffixRules = const [],
    this.defaultUpstreamTag = 'dns-public',
    this.includeReverseZones = false,
    this.searchDomains = const [],
  });

  /// Default DoH/DoT resolver for unmatched public names.
  final String publicResolver;

  /// Extra resolvers (e.g. internal DNS via an inner chain).
  final List<DnsUpstream> upstreams;

  /// Suffix → upstream routing inside the core.
  final List<DnsSuffixRule> suffixRules;

  /// sing-box `dns.final` — which upstream tag handles unmatched queries.
  final String defaultUpstreamTag;

  /// When true and [suffixRules] is non-empty, adds `.in-addr.arpa` to the
  /// first custom upstream (reverse lookups for private zones).
  final bool includeReverseZones;

  /// Written into macOS search domains on connect (FR-17), not used by core DNS.
  final List<String> searchDomains;

  /// First resolver from [publicResolver] after parsing comma-separated input.
  String get primaryResolver => primaryPublicResolver(publicResolver);

  /// All resolvers from [publicResolver] after parsing.
  List<String> get resolverList => parsePublicResolvers(publicResolver);

  /// Normalized comma-separated storage form.
  String get formattedResolvers => formatPublicResolvers(resolverList);
}
