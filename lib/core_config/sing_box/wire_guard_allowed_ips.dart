import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/target_kind.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Computes WireGuard peer [allowed_ips] from routing policy (AR §5.4).
abstract final class WireGuardAllowedIps {
  static List<String> forChain({
    required String chainId,
    required TunnelConfig tunnel,
    required WireGuardProfile wg,
    required bool includeIpv6Default,
  }) {
    final isDefault =
        tunnel.routing.defaultTarget.kind == TargetKind.chain &&
        tunnel.routing.defaultTarget.chainId == chainId;

    if (isDefault) {
      return includeIpv6Default ? ['0.0.0.0/0', '::/0'] : ['0.0.0.0/0'];
    }

    final cidrs = <String>{};
    for (final rule in tunnel.routing.sortedOverrides()) {
      if (rule.target.kind == TargetKind.chain &&
          rule.target.chainId == chainId &&
          rule.matcher.type == MatcherType.ipCidr) {
        cidrs.addAll(rule.matcher.values);
      }
    }

    if (cidrs.isEmpty && wg.allowedIps.isNotEmpty) {
      cidrs.addAll(wg.allowedIps);
    }

    if (cidrs.isEmpty && tunnel.routing.referencedChainIds().contains(chainId)) {
      final domainOnly = tunnel.routing.overrides.any(
        (rule) =>
            rule.target.kind == TargetKind.chain &&
            rule.target.chainId == chainId &&
            rule.matcher.type == MatcherType.domainSuffix,
      );
      if (domainOnly && !isDefault) {
        cidrs.addAll(ConfigConstants.splitCorpCidrs);
        for (final dns in wg.dnsServers) {
          cidrs.add('$dns/32');
        }
      } else {
        cidrs.addAll(
          includeIpv6Default ? ['0.0.0.0/0', '::/0'] : ['0.0.0.0/0'],
        );
      }
    }

    return cidrs.toList()..sort();
  }
}
