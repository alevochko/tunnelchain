import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/ui/widgets/packet_layers_card.dart';

/// Builds Status-screen packet path from routing rules and chains.
class ChainVisualization {
  const ChainVisualization();

  List<RoutePacketPath> routingPaths({
    required RoutingPolicy routing,
    required Map<String, Chain> chainsById,
    required Map<String, Profile> profiles,
    int mtu = 1280,
  }) {
    final paths = <RoutePacketPath>[];

    paths.add(
      _pathForTarget(
        label: 'Default route',
        target: routing.defaultTarget,
        chainsById: chainsById,
        profiles: profiles,
        mtu: mtu,
        isDefault: true,
      ),
    );

    for (final rule in routing.sortedOverrides()) {
      paths.add(
        _pathForTarget(
          label: _matcherLabel(rule.matcher),
          target: rule.target,
          chainsById: chainsById,
          profiles: profiles,
          mtu: mtu,
        ),
      );
    }

    return paths;
  }

  RoutePacketPath _pathForTarget({
    required String label,
    required RouteTarget target,
    required Map<String, Chain> chainsById,
    required Map<String, Profile> profiles,
    required int mtu,
    bool isDefault = false,
  }) {
    if (target.isDirect) {
      return RoutePacketPath(
        label: label,
        targetLabel: 'Direct · local network',
        hops: directPacketHops(),
        encapsulation: [
          EncapLayer(
            label: 'Application payload',
            summary: '',
            overhead: 'MTU $mtu',
            color: AppColors.stopped,
            isPayload: true,
          ),
        ],
        isDefault: isDefault,
      );
    }

    final chain = chainsById[target.chainId];
    return RoutePacketPath(
      label: label,
      targetLabel: chain?.name ?? target.chainId ?? '—',
      hops: packetHops(chain: chain, profiles: profiles),
      encapsulation: encapsulation(chain: chain, profiles: profiles, mtu: mtu),
      isDefault: isDefault,
    );
  }

  String _matcherLabel(RuleMatcher matcher) {
    final values = matcher.values.join(', ');
    if (values.isNotEmpty) return values;
    return switch (matcher.type) {
      MatcherType.ipCidr => 'IP / CIDR',
      MatcherType.domainSuffix => 'Domain suffix',
      MatcherType.port => 'Port',
      MatcherType.process => 'Process',
      MatcherType.geoip => 'GeoIP',
    };
  }

  List<PacketHop> directPacketHops() {
    return const [
      PacketHop(
        title: 'This Mac',
        detail: 'Application',
        tileStyle: HopTileStyle.neutral,
      ),
      PacketHop(
        title: 'Direct',
        detail: 'Local interface · no tunnel',
        linkLabel: 'local',
        linkStyle: HopLinkStyle.muted,
        tileStyle: HopTileStyle.neutral,
      ),
      PacketHop(
        title: 'Egress',
        detail: 'internet',
        linkLabel: 'internet',
        linkStyle: HopLinkStyle.muted,
        tileStyle: HopTileStyle.egress,
      ),
    ];
  }

  List<PacketHop> packetHops({
    required Chain? chain,
    required Map<String, Profile> profiles,
    String? localAddress,
  }) {
    final hops = <PacketHop>[
      PacketHop(
        title: 'This Mac',
        detail: localAddress != null ? 'utun · $localAddress' : 'Application',
        tileStyle: HopTileStyle.neutral,
      ),
    ];

    if (chain == null) {
      hops.add(
        const PacketHop(
          title: 'Egress',
          detail: 'No chain configured',
          linkLabel: '—',
          linkStyle: HopLinkStyle.muted,
          tileStyle: HopTileStyle.egress,
        ),
      );
      return hops;
    }

    for (var i = 0; i < chain.hopProfileIds.length; i++) {
      final profile = profiles[chain.hopProfileIds[i]];
      if (profile == null) continue;
      hops.add(_hopForProfile(profile, isFirst: i == 0));
    }

    final egressDetail = _egressDetail(chain, profiles);
    hops.add(
      PacketHop(
        title: 'Egress',
        detail: egressDetail,
        linkLabel: chain.hopProfileIds.length > 1 ? 'any' : 'internet',
        linkStyle: HopLinkStyle.muted,
        tileStyle: HopTileStyle.egress,
      ),
    );
    return hops;
  }

  List<VisibilityRow> visibility({
    required Chain? chain,
    required Map<String, Profile> profiles,
  }) {
    if (chain == null || chain.hopProfileIds.isEmpty) {
      return const [
        VisibilityRow(
          who: '—',
          what: 'Configure a chain on Chains',
          color: AppColors.stopped,
        ),
      ];
    }

    final rows = <VisibilityRow>[];
    VlessProfile? vless;
    WireGuardProfile? wg;

    for (final id in chain.hopProfileIds) {
      final p = profiles[id];
      if (p is VlessProfile) vless = p;
      if (p is WireGuardProfile) wg = p;
    }

    if (vless != null) {
      final hidesSni = vless.security.toLowerCase() == 'reality';
      rows.add(
        VisibilityRow(
          who: 'ISP',
          what: hidesSni
              ? 'TLS to VPS only (REALITY hides SNI)'
              : 'TLS to ${vless.host}:${vless.port}',
          color: AppColors.accent,
        ),
      );
      if (wg != null) {
        rows.add(
          const VisibilityRow(
            who: 'VPS host',
            what: 'Encrypted WireGuard to inner peer',
            color: AppColors.running,
          ),
        );
        final allowed = wg.allowedIps.isNotEmpty
            ? wg.allowedIps.join(', ')
            : 'internet';
        rows.add(
          VisibilityRow(
            who: wg.name,
            what: 'Plain traffic to $allowed',
            color: AppColors.stopped,
          ),
        );
      } else {
        rows.add(
          VisibilityRow(
            who: vless.name,
            what: 'Decrypted traffic to internet',
            color: AppColors.stopped,
          ),
        );
      }
    }

    return rows;
  }

  List<EncapLayer> encapsulation({
    required Chain? chain,
    required Map<String, Profile> profiles,
    int mtu = 1280,
  }) {
    if (chain == null || chain.hopProfileIds.isEmpty) {
      return [
        EncapLayer(
          label: 'Application payload',
          summary: '',
          overhead: 'MTU $mtu',
          color: AppColors.stopped,
          isPayload: true,
        ),
      ];
    }

    final layers = <EncapLayer>[];
    for (final id in chain.hopProfileIds) {
      final p = profiles[id];
      if (p is VlessProfile) {
        layers.add(
          EncapLayer(
            label: layers.isEmpty ? 'Outer hop' : 'Proxy hop',
            summary:
                'VLESS ${p.security.toUpperCase()} · ${p.transport.toUpperCase()} :${p.port}',
            overhead: '+40 B',
            color: AppColors.accent,
          ),
        );
      } else if (p is WireGuardProfile) {
        final proto = p.obfuscation != null ? 'AWG' : 'WireGuard';
        layers.add(
          EncapLayer(
            label: layers.isEmpty ? 'Hop' : 'Inner hop',
            summary: '$proto · UDP :${p.endpointPort}',
            overhead: '+60 B',
            color: AppColors.running,
          ),
        );
        mtu = p.mtu;
      }
    }

    layers.add(
      EncapLayer(
        label: 'Application payload',
        summary: '',
        overhead: 'MTU $mtu',
        color: AppColors.stopped,
        isPayload: true,
      ),
    );
    return layers;
  }

  PacketHop _hopForProfile(Profile profile, {required bool isFirst}) {
    if (profile is VlessProfile) {
      return PacketHop(
        title: profile.name,
        detail: '${profile.host}:${profile.port}',
        linkLabel: profile.security.toLowerCase() == 'reality' ? 'TLS' : 'TCP',
        linkStyle: HopLinkStyle.accent,
        tileStyle: HopTileStyle.accent,
      );
    }
    if (profile is WireGuardProfile) {
      return PacketHop(
        title: profile.name,
        detail: '${profile.endpointHost}:${profile.endpointPort}',
        linkLabel: 'UDP',
        linkStyle: HopLinkStyle.success,
        tileStyle: HopTileStyle.success,
      );
    }
    return PacketHop(
      title: profile.name,
      detail: profile.protocol.name,
      tileStyle: HopTileStyle.neutral,
    );
  }

  String _egressDetail(Chain chain, Map<String, Profile> profiles) {
    for (final id in chain.hopProfileIds.reversed) {
      final p = profiles[id];
      if (p is WireGuardProfile && p.allowedIps.isNotEmpty) {
        return '${p.allowedIps.join(', ')} · internet';
      }
    }
    return 'internet';
  }
}
