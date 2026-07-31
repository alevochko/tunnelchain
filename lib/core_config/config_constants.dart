/// Fixed network constants shared with the bash prototype.
abstract final class ConfigConstants {
  static const tunAddr4 = '172.19.0.1/30';
  static const tunAddr6 = 'fdfe:dcba:9876::1/126';
  static const dnsPinIp = '172.19.0.2';
  static const clashApiHost = '127.0.0.1:9090';
  static const packetEncoding = 'xudp';

  /// Corp subnets routed into split-referenced WG chains (must match peer allowed_ips).
  static const splitCorpCidrs = ['10.0.0.0/8', '172.20.0.0/16'];

  /// LAN/private ranges — documented for manual split-route setups; not emitted
  /// on TUN auto_route because 172.19.0.0/30 (dns pin) lies inside 172.16.0.0/12.
  static const routeExcludePrivate = [
    '127.0.0.0/8',
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    'fc00::/7',
  ];
}
