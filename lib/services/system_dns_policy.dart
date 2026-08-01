import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/core_config/connect_topology.dart' as topology;
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';

/// Chooses macOS system DNS: WireGuard.app-style direct resolvers vs sing-box pin.
///
/// ## DNS pin (`172.19.0.2`)
///
/// macOS is pointed at [ConfigConstants.dnsPinIp]; sing-box hijacks UDP/53 to that
/// address and applies its own `dns` rules (ADR-007). Needed when:
///
/// - **Split routing** uses several chains in one profile (default + overrides).
/// - **Domain-based routing** (`domain_suffix` rules) — TUN must sniff/resolve names.
/// - **Split DNS** in the core (`dns.suffixRules`, `dns.upstreams`) — different
///   query classes go to different resolvers (corp vs public DoH).
///
/// Pin is **not** required for nested hops inside a single chain (VLESS→WG): that is
/// still one chain; corp DNS can be set on the OS like WireGuard.app if all lookups
/// use the same resolver list.
///
/// ## Native system DNS
///
/// `networksetup` gets the profile's IPv4 resolvers directly.
/// Queries reach them through the tunnel via normal routing — same path as WireGuard.app.
abstract final class SystemDnsPolicy {
  /// True when [systemDnsServers] will return profile resolvers, not the pin.
  static bool usesNativeSystemDns(ConnectBundle bundle) {
    if (!_canUseNativeSystemDns(bundle.tunnel)) {
      return false;
    }
    return _ipv4Resolvers(bundle.tunnel.dns).isNotEmpty;
  }

  /// Resolvers passed to `networksetup` on connect.
  static List<String> serversForConnect(ConnectBundle bundle) =>
      systemDnsServers(bundle);

  static List<String> systemDnsServers(ConnectBundle bundle) {
    if (!_canUseNativeSystemDns(bundle.tunnel)) {
      return const [ConfigConstants.dnsPinIp];
    }

    final ips = _ipv4Resolvers(bundle.tunnel.dns);
    if (ips.isEmpty) {
      return const [ConfigConstants.dnsPinIp];
    }

    return ips;
  }

  /// Search domains for `networksetup` (WireGuard.app parity in native DNS mode).
  static List<String> searchDomainsForConnect(ConnectBundle bundle) {
    final fromPolicy = bundle.tunnel.dns.searchDomains;
    if (fromPolicy.isNotEmpty) return fromPolicy;

    if (!_canUseNativeSystemDns(bundle.tunnel)) {
      return const [];
    }

    final wg = _defaultWireGuardHop(bundle);
    return wg?.searchDomains ?? const [];
  }

  static WireGuardProfile? _defaultWireGuardHop(ConnectBundle bundle) {
    final hop = topology.defaultHopProfile(
      routing: bundle.tunnel.routing,
      chains: bundle.chains,
      profiles: bundle.profiles,
    );
    return hop is WireGuardProfile ? hop : null;
  }

  static bool _canUseNativeSystemDns(TunnelConfig tunnel) {
    final routing = tunnel.routing;

    // Составной профиль: больше одного chain в routing (default + overrides).
    if (routing.referencedChainIds().length != 1) {
      return false;
    }

    // Domain suffix routing needs TUN hijack + sing-box sniff (ADR-007).
    if (topology.needsDomainBasedRouting(routing)) {
      return false;
    }

    // Split DNS inside sing-box (corp suffix → corp resolver, public → DoH).
    if (tunnel.dns.suffixRules.isNotEmpty || tunnel.dns.upstreams.isNotEmpty) {
      return false;
    }

    return true;
  }

  static List<String> _ipv4Resolvers(DnsPolicy dns) {
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    return [
      for (final server in dns.resolverList)
        if (ipv4.hasMatch(server) && server != ConfigConstants.dnsPinIp)
          server,
    ];
  }
}
