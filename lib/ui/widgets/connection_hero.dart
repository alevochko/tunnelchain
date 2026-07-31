import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/app/theme/tunnel_status.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

class HeroVisualStyle {
  const HeroVisualStyle({
    required this.glow,
    required this.ring,
    required this.buttonBg,
    required this.buttonFg,
    required this.pillBg,
    required this.pillFg,
    required this.pulseDot,
  });

  final Color glow;
  final Color ring;
  final Color buttonBg;
  final Color buttonFg;
  final Color pillBg;
  final Color pillFg;
  final bool pulseDot;

  static HeroVisualStyle forStatus(
    TunnelVisualStatus status,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? AppColors.accent : AppColors.accentLight;
    final running = isDark ? AppColors.running : AppColors.runningLight;
    final failed = isDark ? AppColors.failed : AppColors.failedLight;
    final stopped = AppColors.stopped;
    final degraded = isDark ? AppColors.degraded : AppColors.degradedLight;
    final buttonBg = isDark ? AppColors.darkBackground : AppColors.lightSurface;
    final buttonBgMuted = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return switch (status) {
      TunnelVisualStatus.running => HeroVisualStyle(
        glow: running.withValues(alpha: isDark ? 0.18 : 0.10),
        ring: running.withValues(alpha: isDark ? 0.55 : 0.40),
        buttonBg: buttonBg,
        buttonFg: running,
        pillBg: AppColors.runningBg(brightness),
        pillFg: running,
        pulseDot: true,
      ),
      TunnelVisualStatus.connecting || TunnelVisualStatus.resetting =>
        HeroVisualStyle(
          glow: accent.withValues(alpha: isDark ? 0.16 : 0.10),
          ring: accent.withValues(alpha: isDark ? 0.5 : 0.38),
          buttonBg: buttonBgMuted,
          buttonFg: accent,
          pillBg: AppColors.accentBg(brightness),
          pillFg: accent,
          pulseDot: true,
        ),
      TunnelVisualStatus.degraded || TunnelVisualStatus.awaitingConfirm =>
        HeroVisualStyle(
          glow: degraded.withValues(alpha: isDark ? 0.14 : 0.09),
          ring: degraded.withValues(alpha: isDark ? 0.5 : 0.38),
          buttonBg: buttonBgMuted,
          buttonFg: degraded,
          pillBg: AppColors.warningBg(brightness),
          pillFg: degraded,
          pulseDot: false,
        ),
      TunnelVisualStatus.failed => HeroVisualStyle(
        glow: failed.withValues(alpha: isDark ? 0.14 : 0.09),
        ring: failed.withValues(alpha: isDark ? 0.5 : 0.38),
        buttonBg: buttonBgMuted,
        buttonFg: failed,
        pillBg: AppColors.errorBg(brightness),
        pillFg: failed,
        pulseDot: false,
      ),
      TunnelVisualStatus.stopped => HeroVisualStyle(
        glow: stopped.withValues(alpha: isDark ? 0.08 : 0.06),
        ring: stopped.withValues(alpha: isDark ? 0.35 : 0.28),
        buttonBg: buttonBgMuted,
        buttonFg: stopped,
        pillBg: stopped.withValues(alpha: isDark ? 0.12 : 0.08),
        pillFg: stopped,
        pulseDot: false,
      ),
    };
  }
}

/// Hero connect card from design-system/MASTER.md.
class ConnectionHeroCard extends StatelessWidget {
  const ConnectionHeroCard({
    required this.status,
    required this.onPressed,
    super.key,
    this.busy = false,
    this.enabled = true,
    this.externalIp,
    this.uptime,
    this.subtitle,
    this.footer,
  });

  final TunnelVisualStatus status;
  final VoidCallback? onPressed;
  final bool busy;
  final bool enabled;
  final String? externalIp;
  final Duration? uptime;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final style = HeroVisualStyle.forStatus(status, brightness);
    final secondary = AppThemeTokens.of(context).textSecondary;
    final isDark = brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.heroCardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 38, 22, 34),
        child: Column(
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 214,
                    height: 214,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.glow,
                      boxShadow: [
                        BoxShadow(
                          color: style.glow,
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 186,
                    height: 186,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: style.ring),
                    ),
                  ),
                  Material(
                    color: style.buttonBg,
                    shape: const CircleBorder(),
                    child: ActionInkWell(
                      customBorder: const CircleBorder(),
                      enabled: enabled && !busy,
                      onTap: onPressed,
                      child: Container(
                        width: 158,
                        height: 158,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: style.buttonBg,
                          border: isDark
                              ? null
                              : Border.all(
                                  color: style.ring.withValues(alpha: 0.35),
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: style.ring.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: busy
                            ? SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: style.buttonFg,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PowerIcon(color: style.buttonFg),
                                  const SizedBox(height: 9),
                                  Text(
                                    _heroLabel(status),
                                    style: AppTypography.heroLabel.copyWith(
                                      color: style.buttonFg,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusPill(
                        label: status.label,
                        color: style.pillFg,
                        background: style.pillBg,
                      ),
                      if (externalIp != null) ...[
                        _MetricInline(label: 'IP', value: externalIp!),
                        _DotSeparator(color: Theme.of(context).dividerColor),
                      ],
                      if (uptime != null)
                        _MetricInline(
                          label: 'Uptime',
                          value: _formatUptime(uptime!),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: AppTypography.body135.copyWith(color: secondary),
                    ),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 14),
                    Center(child: footer!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _heroLabel(TunnelVisualStatus status) {
    return switch (status) {
      TunnelVisualStatus.stopped => 'Connect',
      TunnelVisualStatus.connecting => 'Connecting',
      TunnelVisualStatus.running => 'Disconnect',
      TunnelVisualStatus.degraded => 'Disconnect',
      TunnelVisualStatus.failed => 'Retry',
      TunnelVisualStatus.awaitingConfirm => 'Disconnect',
      TunnelVisualStatus.resetting => 'Resetting',
    };
  }

  static String _formatUptime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

class _PowerIcon extends StatelessWidget {
  const _PowerIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _PowerIconPainter(color: color),
    );
  }
}

class _PowerIconPainter extends CustomPainter {
  _PowerIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(12 * s, 3.5 * s), Offset(12 * s, 11.5 * s), paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(12 * s, 12 * s),
        width: 15 * s,
        height: 15 * s,
      ),
      2.4,
      4.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PowerIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.statusPill.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MetricInline extends StatelessWidget {
  const _MetricInline({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.sectionHeader.copyWith(
            color: secondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          value,
          style: AppTypography.mono145.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
