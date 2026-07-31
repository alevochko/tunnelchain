/// Supported and planned node types for the Nodes import UI.
enum ProxyNodeKind {
  vless(supported: true),
  hysteria(supported: false),
  hysteria2(supported: false),
  trojan(supported: false),
  shadowsocks(supported: false),
  socks(supported: false),
  http(supported: false);

  const ProxyNodeKind({required this.supported});

  final bool supported;

  String get label => switch (this) {
    ProxyNodeKind.vless => 'VLESS',
    ProxyNodeKind.hysteria => 'Hysteria',
    ProxyNodeKind.hysteria2 => 'Hysteria2',
    ProxyNodeKind.trojan => 'Trojan',
    ProxyNodeKind.shadowsocks => 'Shadowsocks',
    ProxyNodeKind.socks => 'SOCKS5',
    ProxyNodeKind.http => 'HTTP',
  };
}

enum VpnNodeKind {
  wireGuard(supported: true),
  amneziaWg(supported: false);

  const VpnNodeKind({required this.supported});

  final bool supported;

  String get label => switch (this) {
    VpnNodeKind.wireGuard => 'WireGuard',
    VpnNodeKind.amneziaWg => 'AmneziaWG',
  };
}

enum NodeImportKind {
  proxyVless,
  vpnWireGuard,
}
