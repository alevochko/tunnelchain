import 'package:tunnel_chain/core_config/config_constants.dart';

/// Validates sing-box config invariants from AR §5.3.
class ConfigInvariants {
  static void assertAll(Map<String, dynamic> config) {
    if (_usesLauncherRoute(config)) {
      _assertLauncherRoute(config);
      assertDnsServerCount(config);
    } else {
      assertDnsRuleOrder(config);
      assertDnsServerCount(config);
    }
    assertAutoDetectInterface(config);
    assertBootstrapResolver(config);
    assertNestedHopResolvers(config);
    assertWireGuardDetourNotDirect(config);
    if (_usesLauncherRoute(config) && _isWgOnlyLauncher(config)) {
      assertFindProcess(config);
    }
  }

  static bool _isSplitRouting(Map<String, dynamic> config) {
    final route = config['route'] as Map<String, dynamic>?;
    return route?['final'] == 'direct';
  }

  static bool _isWgOnlyLauncher(Map<String, dynamic> config) {
    if (!_hasWireGuardEndpoints(config)) return false;
    final route = config['route'] as Map<String, dynamic>?;
    if (route?['final'] == 'direct') return false;
    final outbounds = config['outbounds'] as List<dynamic>? ?? [];
    return !outbounds.any((o) => (o as Map<String, dynamic>)['type'] == 'vless');
  }

  static bool _hasWireGuardEndpoints(Map<String, dynamic> config) {
    final endpoints = config['endpoints'] as List<dynamic>? ?? [];
    return endpoints.isNotEmpty;
  }

  static int _launcherRouteOffset(List<dynamic> rules) {
    if (rules.isEmpty) return -1;
    final first = rules.first as Map<String, dynamic>;
    if (first['action'] == 'hijack-dns' && first['ip_cidr'] is List) {
      if (rules.length < 2) return -1;
      return (rules[1] as Map)['action'] == 'resolve' ? 1 : -1;
    }
    if (first['action'] == 'resolve') return 0;
    return -1;
  }

  static bool _usesLauncherRoute(Map<String, dynamic> config) {
    final rules = config['route']?['rules'] as List<dynamic>? ?? [];
    return _launcherRouteOffset(rules) >= 0;
  }

  static void _assertLauncherRoute(Map<String, dynamic> config) {
    final rules = config['route']?['rules'] as List<dynamic>? ?? [];
    final offset = _launcherRouteOffset(rules);
    if (offset < 0 || rules.length < offset + 3) {
      throw ConfigInvariantException(
        'Launcher TUN route must dns-pin, resolve, sniff, then hijack-dns',
      );
    }

    if (offset == 1) {
      final pin = rules[0] as Map<String, dynamic>;
      if (pin['action'] != 'hijack-dns' || pin['ip_cidr'] is! List) {
        throw ConfigInvariantException(
          'Launcher route must start with dns-pin hijack-dns',
        );
      }
    }

    final resolve = rules[offset] as Map<String, dynamic>;
    if (resolve['inbound'] != 'tun-in' || resolve['action'] != 'resolve') {
      throw ConfigInvariantException(
        'Launcher route must include tun-in resolve after dns-pin',
      );
    }

    final sniff = rules[offset + 1] as Map<String, dynamic>;
    if (sniff['inbound'] != 'tun-in' || sniff['action'] != 'sniff') {
      throw ConfigInvariantException(
        'Launcher route must include tun-in sniff after resolve',
      );
    }

    final hijack = rules[offset + 2] as Map<String, dynamic>;
    if (hijack['protocol'] != 'dns' || hijack['action'] != 'hijack-dns') {
      throw ConfigInvariantException(
        'Launcher route must end with protocol:dns hijack-dns',
      );
    }

    final tun = (config['inbounds'] as List?)?.first as Map<String, dynamic>?;
    final relaxedRoute = _isWgOnlyLauncher(config) || _isSplitRouting(config);
    if (relaxedRoute) {
      if (tun?['strict_route'] != false) {
        throw ConfigInvariantException(
          'WG-only/split TUN must set strict_route false',
        );
      }
    } else {
      if (tun?['strict_route'] != true) {
        throw ConfigInvariantException(
          'Proxy/nested TUN must set strict_route true',
        );
      }
    }
    if (tun?.containsKey('route_exclude_address') == true) {
      throw ConfigInvariantException(
        'TUN must not set route_exclude_address (breaks dns pin ${ConfigConstants.dnsPinIp})',
      );
    }
    if (tun?['stack'] != 'system') {
      throw ConfigInvariantException('Launcher TUN must use stack system');
    }
  }

  static void assertDnsRuleOrder(Map<String, dynamic> config) {
    final route = config['route'] as Map<String, dynamic>?;
    final rules = route?['rules'] as List<dynamic>? ?? [];
    if (rules.length < 3) {
      throw ConfigInvariantException(
        'route.rules must have at least 3 entries',
      );
    }

    final first = rules[0] as Map<String, dynamic>;
    if (first['action'] != 'hijack-dns' ||
        first['ip_cidr'] is! List ||
        first['port'] is! List) {
      throw ConfigInvariantException(
        'First route rule must be ip_cidr+port hijack-dns',
      );
    }

    final second = rules[1] as Map<String, dynamic>;
    if (second['action'] != 'sniff') {
      throw ConfigInvariantException('Second route rule must be sniff');
    }

    final third = rules[2] as Map<String, dynamic>;
    if (third['protocol'] != 'dns' || third['action'] != 'hijack-dns') {
      throw ConfigInvariantException(
        'Third route rule must be protocol:dns hijack-dns',
      );
    }

    _assertProxyTun(config);
  }

  static void _assertProxyTun(Map<String, dynamic> config) {
    if (_isWgOnlyLauncher(config) || _isSplitRouting(config)) return;
    final tun = (config['inbounds'] as List?)?.first as Map<String, dynamic>?;
    if (tun?['strict_route'] != true) {
      throw ConfigInvariantException(
        'Proxy/nested TUN must set strict_route true',
      );
    }
    if (tun?.containsKey('route_exclude_address') == true) {
      throw ConfigInvariantException(
        'TUN must not set route_exclude_address (breaks dns pin ${ConfigConstants.dnsPinIp})',
      );
    }
    if (tun?['stack'] != 'system') {
      throw ConfigInvariantException('TUN must use stack system');
    }
  }

  static void assertDnsServerCount(Map<String, dynamic> config) {
    final dns = config['dns'] as Map<String, dynamic>?;
    final servers = dns?['servers'] as List<dynamic>? ?? [];
    if (servers.length < 2) {
      throw ConfigInvariantException(
        'dns.servers must have at least bootstrap + public',
      );
    }

    final tags = servers
        .map((s) => (s as Map<String, dynamic>)['tag'] as String)
        .toSet();
    for (final required in ['dns-bootstrap', 'dns-public']) {
      if (!tags.contains(required)) {
        throw ConfigInvariantException('Missing DNS server tag: $required');
      }
    }
  }

  static void assertAutoDetectInterface(Map<String, dynamic> config) {
    final route = config['route'] as Map<String, dynamic>?;
    if (route?['auto_detect_interface'] != true) {
      throw ConfigInvariantException(
        'route.auto_detect_interface must be true',
      );
    }
  }

  static void assertFindProcess(Map<String, dynamic> config) {
    final route = config['route'] as Map<String, dynamic>?;
    if (route?['find_process'] != true) {
      throw ConfigInvariantException('route.find_process must be true');
    }
  }

  static void assertBootstrapResolver(Map<String, dynamic> config) {
    final outbounds = config['outbounds'] as List<dynamic>? ?? [];
    for (final ob in outbounds) {
      final map = ob as Map<String, dynamic>;
      if (map.containsKey('domain_resolver') &&
          map['domain_resolver'] != 'dns-bootstrap') {
        throw ConfigInvariantException(
          'Outermost hop must use domain_resolver dns-bootstrap',
        );
      }
    }
  }

  /// Inner hops must use dns-via-{chainId}, not a hardcoded protocol name.
  static void assertNestedHopResolvers(Map<String, dynamic> config) {
    final endpoints = config['endpoints'] as List<dynamic>? ?? [];
    for (final ep in endpoints) {
      final map = ep as Map<String, dynamic>;
      if (map['type'] != 'wireguard') continue;
      final resolver = map['domain_resolver'] as String?;
      if (resolver == null || resolver == 'dns-bootstrap') continue;
      if (!resolver.startsWith('dns-via-')) {
        throw ConfigInvariantException(
          'Inner hop domain_resolver must be dns-via-<chainId>, got $resolver',
        );
      }
    }
  }

  /// sing-box rejects `detour: direct` on wireguard endpoints.
  static void assertWireGuardDetourNotDirect(Map<String, dynamic> config) {
    final endpoints = config['endpoints'] as List<dynamic>? ?? [];
    for (final ep in endpoints) {
      final map = ep as Map<String, dynamic>;
      if (map['type'] != 'wireguard') continue;
      if (map['detour'] == 'direct') {
        throw ConfigInvariantException(
          'WireGuard endpoint must not set detour to direct',
        );
      }
    }
  }
}

class ConfigInvariantException implements Exception {
  ConfigInvariantException(this.message);
  final String message;
  @override
  String toString() => message;
}
