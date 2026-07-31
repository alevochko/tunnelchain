import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';
import 'package:tunnel_chain/ui/widgets/traffic_sparkline.dart';

enum HopLinkStyle { none, accent, success, muted }

class PacketHop {
  const PacketHop({
    required this.title,
    required this.detail,
    this.linkLabel,
    this.linkStyle = HopLinkStyle.none,
    this.tileStyle = HopTileStyle.neutral,
  });

  final String title;
  final String detail;
  final String? linkLabel;
  final HopLinkStyle linkStyle;
  final HopTileStyle tileStyle;
}

enum HopTileStyle { neutral, accent, success, egress }

class EncapLayer {
  const EncapLayer({
    required this.label,
    required this.summary,
    required this.overhead,
    required this.color,
    this.isPayload = false,
  });

  final String label;
  final String summary;
  final String overhead;
  final Color color;
  final bool isPayload;
}

class VisibilityRow {
  const VisibilityRow({
    required this.who,
    required this.what,
    required this.color,
  });

  final String who;
  final String what;
  final Color color;
}

/// One routing target (default or override) with its hop stack.
class RoutePacketPath {
  const RoutePacketPath({
    required this.label,
    required this.targetLabel,
    required this.hops,
    this.encapsulation = const [],
    this.isDefault = false,
  });

  final String label;
  final String targetLabel;
  final List<PacketHop> hops;
  final List<EncapLayer> encapsulation;
  final bool isDefault;
}

class PacketLayersPanel extends StatelessWidget {
  const PacketLayersPanel({
    this.routes = const [],
    this.hops = const [],
    this.encapsulation = const [],
    super.key,
  });

  final List<RoutePacketPath> routes;
  final List<PacketHop> hops;
  final List<EncapLayer> encapsulation;

  @override
  Widget build(BuildContext context) {
    final routePaths = routes.isNotEmpty
        ? routes
        : [
            if (hops.isNotEmpty)
              RoutePacketPath(
                label: 'Route',
                targetLabel: '',
                hops: hops,
                encapsulation: encapsulation,
              ),
          ];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionOverline('Packet layers', bottom: 16),
          if (routePaths.isEmpty)
            Text(
              'No routes configured',
              style: AppTypography.body14.copyWith(
                color: AppThemeTokens.of(context).textSecondary,
              ),
            )
          else
            for (var i = 0; i < routePaths.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                const SizedBox(height: 16),
              ],
              _RoutePathSection(
                path: routePaths[i],
                showHeader: routePaths.length > 1,
              ),
            ],
        ],
      ),
    );
  }
}

class _RoutePathSection extends StatelessWidget {
  const _RoutePathSection({
    required this.path,
    required this.showHeader,
  });

  final RoutePacketPath path;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    final accent = path.isDefault
        ? Theme.of(context).colorScheme.primary
        : secondary;
    final borderColor = path.isDefault
        ? accent.withValues(alpha: 0.42)
        : Theme.of(context).dividerColor;
    final surface = Theme.of(context).scaffoldBackgroundColor;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.label,
                      style: AppTypography.mono12.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (path.targetLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        path.targetLabel,
                        style: AppTypography.body14.copyWith(
                          color: secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (path.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'default',
                    style: AppTypography.mono12.copyWith(color: accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _VerticalHopStack(hops: path.hops),
        if (path.encapsulation.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionOverline('Encapsulation', bottom: 8),
          _EncapsulationStack(layers: path.encapsulation),
        ],
      ],
    );

    if (!showHeader) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: content,
      ),
    );
  }
}

class VisibilityPanel extends StatelessWidget {
  const VisibilityPanel({required this.rows, super.key});

  final List<VisibilityRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionOverline('Who sees what', bottom: 16),
          if (rows.isEmpty)
            Text(
              'No chain configured',
              style: AppTypography.body14.copyWith(
                color: AppThemeTokens.of(context).textSecondary,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const _VisibilityStepLink(),
              _VisibilityTile(row: rows[i]),
            ],
        ],
      ),
    );
  }
}

class _VisibilityStepLink extends StatelessWidget {
  const _VisibilityStepLink();

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: CustomPaint(
              size: const Size(28, 24),
              painter: _DownArrowPainter(
                color: secondary.withValues(alpha: 0.55),
                dashed: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'then',
            style: AppTypography.mono12.copyWith(
              color: secondary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({required this.row});

  final VisibilityRow row;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    final bg = row.color.withValues(alpha: 0.07);
    final border = row.color.withValues(alpha: 0.38);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: row.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.who,
                  style: AppTypography.linkMono.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              row.what,
              style: AppTypography.body14.copyWith(
                color: secondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrafficPanel extends StatelessWidget {
  const TrafficPanel({
    required this.uploadBps,
    required this.downloadBps,
    List<TrafficSample>? history,
    this.live = false,
    super.key,
  }) : history = history ?? const <TrafficSample>[];

  final int uploadBps;
  final int downloadBps;
  final List<TrafficSample> history;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uploadColor = isDark ? AppColors.running : AppColors.runningLight;
    final downloadColor = isDark ? AppColors.accent : AppColors.accentLight;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'TRAFFIC',
                style: AppTypography.sectionHeader.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(width: 18),
              Text(
                '↑ ${_formatBps(uploadBps)}',
                style: AppTypography.mono145.copyWith(color: uploadColor),
              ),
              const SizedBox(width: 12),
              Text(
                '↓ ${_formatBps(downloadBps)}',
                style: AppTypography.mono145.copyWith(color: downloadColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TrafficSparkline(
            history: history,
            live: live,
          ),
        ],
      ),
    );
  }

  static String _formatBps(int bps) {
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024 * 1024) {
      return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

class ActiveRoutingPanel extends StatelessWidget {
  const ActiveRoutingPanel({
    required this.activeChain,
    required this.defaultRoute,
    required this.overrideCount,
    super.key,
  });

  final String activeChain;
  final String defaultRoute;
  final int overrideCount;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    final primary = Theme.of(context).colorScheme.primary;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionOverline('Active routing', bottom: 16),
          _RoutingLine(label: 'Active chain', value: activeChain, link: true, linkColor: primary),
          _RoutingLine(
            label: 'Default route',
            value: defaultRoute,
            link: true,
            linkColor: primary,
            borderTop: true,
          ),
          _RoutingLine(
            label: 'Overrides',
            value: '$overrideCount rules',
            borderTop: true,
            valueColor: Theme.of(context).colorScheme.onSurface,
            labelColor: secondary,
          ),
        ],
      ),
    );
  }
}

class _RoutingLine extends StatelessWidget {
  const _RoutingLine({
    required this.label,
    required this.value,
    this.link = false,
    this.linkColor,
    this.borderTop = false,
    this.valueColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final bool link;
  final Color? linkColor;
  final bool borderTop;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final secondary = labelColor ?? AppThemeTokens.of(context).textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: borderTop
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body14.copyWith(color: secondary)),
          Text(
            value,
            style: (link
                    ? AppTypography.body14.copyWith(color: linkColor)
                    : AppTypography.body14.copyWith(color: valueColor))
                .copyWith(fontWeight: link ? FontWeight.w500 : FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _VerticalHopStack extends StatelessWidget {
  const _VerticalHopStack({required this.hops});

  final List<PacketHop> hops;

  @override
  Widget build(BuildContext context) {
    if (hops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < hops.length; i++) ...[
          if (i > 0) _VerticalHopLink(hop: hops[i]),
          _HopTile(hop: hops[i]),
        ],
      ],
    );
  }
}

class _VerticalHopLink extends StatelessWidget {
  const _VerticalHopLink({required this.hop});

  final PacketHop hop;

  @override
  Widget build(BuildContext context) {
    final color = _linkColor(hop.linkStyle);
    final secondary = AppThemeTokens.of(context).textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: CustomPaint(
              size: const Size(28, 28),
              painter: _DownArrowPainter(color: color, dashed: hop.linkStyle == HopLinkStyle.muted),
            ),
          ),
          const SizedBox(width: 10),
          if (hop.linkLabel != null)
            Text(
              hop.linkLabel!,
              style: AppTypography.mono12.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            )
          else
            Text(
              'next hop',
              style: AppTypography.mono12.copyWith(color: secondary),
            ),
        ],
      ),
    );
  }

  Color _linkColor(HopLinkStyle style) {
    return switch (style) {
      HopLinkStyle.accent => AppColors.accent,
      HopLinkStyle.success => AppColors.running,
      HopLinkStyle.muted => AppColors.stopped,
      HopLinkStyle.none => AppColors.stopped,
    };
  }
}

class _DownArrowPainter extends CustomPainter {
  _DownArrowPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cx = 14.0;
    const top = 2.0;
    const bottom = 22.0;

    if (dashed) {
      paint.strokeCap = StrokeCap.butt;
      const dash = 3.0;
      var y = top;
      while (y < bottom - 4) {
        canvas.drawLine(Offset(cx, y), Offset(cx, y + dash), paint);
        y += dash * 2;
      }
    } else {
      canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
    }

    final fill = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 4, bottom - 5)
        ..lineTo(cx, bottom + 2)
        ..lineTo(cx + 4, bottom - 5)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DownArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

class _HopTile extends StatelessWidget {
  const _HopTile({required this.hop});

  final PacketHop hop;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final (border, bg, dot) = switch (hop.tileStyle) {
      HopTileStyle.accent => (AppColors.accent, tokens.accentBg, AppColors.accent),
      HopTileStyle.success => (AppColors.running, tokens.runningBg, AppColors.running),
      HopTileStyle.egress => (Theme.of(context).dividerColor, Theme.of(context).scaffoldBackgroundColor, AppColors.stopped),
      HopTileStyle.neutral => (Theme.of(context).dividerColor, Theme.of(context).scaffoldBackgroundColor, Theme.of(context).colorScheme.onSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hop.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            hop.detail,
            style: AppTypography.mono125.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EncapsulationStack extends StatelessWidget {
  const _EncapsulationStack({required this.layers});

  final List<EncapLayer> layers;

  @override
  Widget build(BuildContext context) {
    if (layers.isEmpty) return const SizedBox.shrink();
    return _buildLayer(context, layers.first, layers.skip(1).toList());
  }

  Widget _buildLayer(
    BuildContext context,
    EncapLayer layer,
    List<EncapLayer> rest,
  ) {
    final tokens = AppThemeTokens.of(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final secondary = tokens.textSecondary;

    if (layer.isPayload) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: _EncapHeader(
          color: Theme.of(context).colorScheme.onSurface,
          label: layer.label,
          summary: layer.summary,
          overhead: layer.overhead,
          overheadColor: secondary,
        ),
      );
    }

    final inner = rest.isNotEmpty ? _buildLayer(context, rest.first, rest.skip(1).toList()) : null;
    final innerBg = layer.color == AppColors.running ? tokens.runningBg : tokens.accentBg;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: layer.color),
        borderRadius: BorderRadius.circular(inner != null ? 12 : 9),
        color: innerBg,
      ),
      padding: const EdgeInsets.all(9),
      child: Column(
        children: [
          _EncapHeader(
            color: layer.color,
            label: layer.label,
            summary: layer.summary,
            overhead: layer.overhead,
            overheadColor: layer.color,
          ),
          if (inner != null) ...[
            const SizedBox(height: 8),
            inner,
          ],
        ],
      ),
    );
  }
}

class _EncapHeader extends StatelessWidget {
  const _EncapHeader({
    required this.color,
    required this.label,
    required this.summary,
    required this.overhead,
    required this.overheadColor,
  });

  final Color color;
  final String label;
  final String summary;
  final String overhead;
  final Color overheadColor;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
        if (summary.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(summary, style: AppTypography.mono12.copyWith(color: secondary)),
        ],
        const Spacer(),
        Text(
          overhead,
          style: AppTypography.sectionHeader.copyWith(
            color: overheadColor,
            fontSize: 11.5,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: child,
      ),
    );
  }
}
