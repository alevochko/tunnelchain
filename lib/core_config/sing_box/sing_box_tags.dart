/// Stable sing-box tags used across configurators.
abstract final class SingBoxTags {
  static String hop(String chainId, int index) => '$chainId-hop$index';

  /// DNS resolver that reaches the public internet through the outer hop of a chain.
  static String outerHopDns(String chainId) => 'dns-via-$chainId';

  static const direct = 'direct';
  static const bootstrapDns = 'dns-bootstrap';
  static const publicDns = 'dns-public';
  static const tunInbound = 'tun-in';
}
