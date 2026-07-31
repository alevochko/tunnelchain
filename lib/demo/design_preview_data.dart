import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
import 'package:tunnel_chain/ui/widgets/packet_layers_card.dart';

abstract final class DesignPreviewData {
  static List<PacketHop> packetHops() {
    final outer = SampleTunnel.outerProfile;
    final inner = SampleTunnel.innerProfile;
    return [
      PacketHop(
        title: 'This Mac',
        detail: 'utun6 · ${inner.addresses.first}',
        tileStyle: HopTileStyle.neutral,
      ),
      PacketHop(
        title: 'VPS Frankfurt',
        detail: '${outer.host}:${outer.port}',
        linkLabel: 'TLS',
        linkStyle: HopLinkStyle.accent,
        tileStyle: HopTileStyle.accent,
      ),
      PacketHop(
        title: 'Corp peer',
        detail: '${inner.endpointHost}:${inner.endpointPort}',
        linkLabel: 'UDP',
        linkStyle: HopLinkStyle.success,
        tileStyle: HopTileStyle.success,
      ),
      const PacketHop(
        title: 'Egress',
        detail: '10.0.0.0/8 · internet',
        linkLabel: 'any',
        linkStyle: HopLinkStyle.muted,
        tileStyle: HopTileStyle.egress,
      ),
    ];
  }

  static List<VisibilityRow> visibility() => const [
    VisibilityRow(
      who: 'ISP',
      what: 'TLS to VPS only (REALITY hides SNI)',
      color: AppColors.accent,
    ),
    VisibilityRow(
      who: 'VPS host',
      what: 'Encrypted WireGuard to corp peer',
      color: AppColors.running,
    ),
    VisibilityRow(
      who: 'Corp peer',
      what: 'Plain traffic to allowed CIDRs',
      color: AppColors.stopped,
    ),
  ];
}
