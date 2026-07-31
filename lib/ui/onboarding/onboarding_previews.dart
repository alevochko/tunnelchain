import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/ui/onboarding/onboarding_animations.dart';
import 'package:tunnel_chain/ui/onboarding/onboarding_data.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';
import 'package:tunnel_chain/ui/widgets/tunnel_chain_logo.dart';

/// Fits preview content; [FittedBox] prevents overflow, scale animates on step changes.
class OnboardingPreviewViewport extends StatefulWidget {
  const OnboardingPreviewViewport({
    required this.step,
    required this.child,
    super.key,
  });

  final int step;
  final Widget child;

  @override
  State<OnboardingPreviewViewport> createState() =>
      _OnboardingPreviewViewportState();
}

class _OnboardingPreviewViewportState extends State<OnboardingPreviewViewport>
    with SingleTickerProviderStateMixin {
  final GlobalKey _measureKey = GlobalKey();
  late final AnimationController _controller;
  double _multiplierBegin = 1.0;
  BoxConstraints? _constraints;

  static final Map<int, Size> _intrinsicSizes = {};

  /// Conservative fallback heights (>= content) for first-time step transitions.
  static const Map<int, double> _fallbackHeights = {
    0: 338,
    1: 190,
    2: 338,
    3: 272,
  };

  /// Scale past the fit box so menu-bar pills peek outside the preview frame.
  static const double _overscale = 1.08;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _multiplierBegin = 1.0;
        }
      });
    SchedulerBinding.instance.addPostFrameCallback((_) => _cacheIntrinsicSize());
  }

  @override
  void didUpdateWidget(covariant OnboardingPreviewViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      _animateStepChange(from: oldWidget.step, to: widget.step);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => _cacheIntrinsicSize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cacheIntrinsicSize() {
    if (!mounted) return;
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _intrinsicSizes[widget.step] = box.size;
  }

  Size _sizeFor(int step, double maxWidth) {
    return _intrinsicSizes[step] ??
        Size(maxWidth, _fallbackHeights[step] ?? 250);
  }

  double _fittedScale(Size childSize, BoxConstraints constraints) {
    if (childSize.width <= 0 || childSize.height <= 0) return 1;
    return math.min(
      1.0,
      math.min(
        constraints.maxWidth / childSize.width,
        constraints.maxHeight / childSize.height,
      ),
    );
  }

  void _animateStepChange({required int from, required int to}) {
    final constraints = _constraints;
    if (constraints == null) return;

    final fromSize = _sizeFor(from, constraints.maxWidth);
    final toSize = _sizeFor(to, constraints.maxWidth);
    final fromScale = _fittedScale(fromSize, constraints);
    final toScale = _fittedScale(toSize, constraints);

    if ((fromScale - toScale).abs() < 0.001) {
      _multiplierBegin = 1.0;
      _controller.value = 1.0;
      return;
    }

    _multiplierBegin = fromScale / toScale;
    _controller.forward(from: 0);
  }

  double get _effectiveMultiplier {
    if (_multiplierBegin == 1.0) return 1.0;
    final t = kTcEase.transform(_controller.value);
    return _multiplierBegin + (1.0 - _multiplierBegin) * t;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _constraints = constraints;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Transform.scale(
            scale: _effectiveMultiplier *
                (widget.step == 3 ? _overscale : 1.0),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: constraints.maxWidth,
                key: _measureKey,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingStepPreview extends StatelessWidget {
  const OnboardingStepPreview({required this.step, super.key});

  final int step;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepTransition(
      step: step,
      child: switch (step) {
        0 => const _NodesPreview(),
        1 => const _ChainPreview(),
        2 => const _ProfilesPreview(),
        _ => const _ConnectPreview(),
      },
    );
  }
}

class _NodesPreview extends StatelessWidget {
  const _NodesPreview();

  static const _proxyKinds = [
    ('VLESS', true),
    ('Hysteria', false),
    ('Hysteria2', false),
    ('Trojan', false),
    ('Shadowsocks', false),
    ('SOCKS5', false),
    ('HTTP', false),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final border = Theme.of(context).dividerColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return TcInAnimation(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionOverline('Add proxy', bottom: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final (label, active) in _proxyKinds)
                _PreviewChip(label: label, active: active),
            ],
          ),
          const SizedBox(height: 10),
          const SectionOverline('Add VPN', bottom: 8),
          const Wrap(
            spacing: 7,
            children: [
              _PreviewChip(label: 'WireGuard', active: true),
              _PreviewChip(label: 'AmneziaWG', active: false),
            ],
          ),
          const SizedBox(height: 12),
          const SectionOverline('Saved nodes', bottom: 8),
          TcUpAnimation(
            delay: const Duration(milliseconds: 120),
            child: _SavedNodePreview(
              name: OnboardingDemoData.homeProxy,
              meta: '${OnboardingDemoData.homeProxyEndpoint} · Added today',
              badge: 'VLESS',
              border: border,
              tokens: tokens,
              onSurface: onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TcUpAnimation(
            delay: const Duration(milliseconds: 240),
            child: _SavedNodePreview(
              name: OnboardingDemoData.officeVpn,
              meta: '${OnboardingDemoData.officeVpnEndpoint} · Added today',
              badge: 'WIREGUARD',
              border: border,
              tokens: tokens,
              onSurface: onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fg = active ? onSurface : tokens.textSecondary;
    final side = active ? onSurface : Theme.of(context).dividerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: side),
      ),
      child: Text(
        label,
        style: AppTypography.body125.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _SavedNodePreview extends StatelessWidget {
  const _SavedNodePreview({
    required this.name,
    required this.meta,
    required this.badge,
    required this.border,
    required this.tokens,
    required this.onSurface,
  });

  final String name;
  final String meta;
  final String badge;
  final Color border;
  final AppThemeTokens tokens;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.body14.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppTypography.mono12.copyWith(color: tokens.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: AppTypography.mono12.copyWith(
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainPreview extends StatefulWidget {
  const _ChainPreview();

  @override
  State<_ChainPreview> createState() => _ChainPreviewState();
}

class _ChainPreviewState extends State<_ChainPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dashController;

  @override
  void initState() {
    super.initState();
    _dashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
  }

  @override
  void dispose() {
    _dashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final secondary = AppThemeTokens.of(context).textSecondary;
    final dash = _dashController;

    return TcInAnimation(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HopTile(
                label: 'Your Mac',
                caption: '▢',
                color: secondary,
                border: border,
                muted: true,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 26, bottom: 22),
                  child: TcDashLine(animation: dash, color: AppColors.accent),
                ),
              ),
              _HopTile(
                label: OnboardingDemoData.homeProxy,
                caption: 'HOP 1',
                protocol: 'VLESS',
                color: AppColors.accent,
                border: AppColors.accent.withValues(alpha: 0.5),
                fill: AppColors.accent.withValues(alpha: 0.14),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 26, bottom: 22),
                  child: TcDashLine(animation: dash, color: AppColors.running),
                ),
              ),
              _HopTile(
                label: OnboardingDemoData.officeVpn,
                caption: 'HOP 2',
                protocol: 'WireGuard',
                color: AppColors.running,
                border: AppColors.running.withValues(alpha: 0.5),
                fill: AppColors.running.withValues(alpha: 0.14),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 26, bottom: 22),
                  child: TcDashLine(animation: dash, color: secondary),
                ),
              ),
              _HopTile(
                label: 'Internet',
                caption: '⊕',
                color: secondary,
                border: border,
                muted: true,
                width: 96,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TcUpAnimation(
            delay: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      OnboardingDemoData.officeViaHome,
                      style: AppTypography.body14.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'VLESS → WireGuard',
                    style: AppTypography.mono125.copyWith(color: secondary),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.running,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '42 ms',
                    style: AppTypography.mono125.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HopTile extends StatelessWidget {
  const _HopTile({
    required this.label,
    required this.caption,
    required this.color,
    required this.border,
    this.protocol,
    this.fill,
    this.muted = false,
    this.width = 118,
  });

  final String label;
  final String caption;
  final String? protocol;
  final Color color;
  final Color border;
  final Color? fill;
  final bool muted;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill ?? AppThemeTokens.of(context).surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Text(
              caption,
              style: muted
                  ? TextStyle(fontSize: 20, color: color)
                  : AppTypography.mono12.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.body125.copyWith(
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
              color: muted
                  ? AppThemeTokens.of(context).textSecondary
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 11.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (protocol != null) ...[
            const SizedBox(height: 2),
            Text(
              protocol!,
              style: AppTypography.mono12.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfilesPreview extends StatelessWidget {
  const _ProfilesPreview();

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final secondary = AppThemeTokens.of(context).textSecondary;

    return TcInAnimation(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionOverline('Profiles', bottom: 0)),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New profile'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TcUpAnimation(
            child: _ProfileCardPreview(
              border: border,
              secondary: secondary,
              title: OnboardingDemoData.everydayBrowsing,
              summary: 'Full tunnel → Home proxy',
              meta: 'Chains: Home proxy · DNS: 1.1.1.1, 8.8.8.8',
            ),
          ),
          const SizedBox(height: 10),
          TcUpAnimation(
            delay: const Duration(milliseconds: 120),
            child: _ProfileCardPreview(
              border: AppColors.running,
              secondary: secondary,
              title: OnboardingDemoData.officeNetwork,
              summary: 'Split tunnel → Office via Home',
              meta: 'Chains: Home proxy → Office VPN · DNS: 10.0.0.53',
              active: true,
              rules: const [
                ('*.corp.internal', 'chain'),
                ('10.0.0.0/8', 'chain'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCardPreview extends StatelessWidget {
  const _ProfileCardPreview({
    required this.border,
    required this.secondary,
    required this.title,
    required this.summary,
    required this.meta,
    this.active = false,
    this.rules = const [],
  });

  final Color border;
  final Color secondary;
  final String title;
  final String summary;
  final String meta;
  final bool active;
  final List<(String, String)> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: active ? 1.5 : 1),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.running.withValues(alpha: 0.08),
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body135.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active) ...[
                Text(
                  'Active',
                  style: AppTypography.body125.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.running,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.edit_outlined, size: 16, color: secondary),
              const SizedBox(width: 8),
              const Icon(Icons.delete_outline, size: 16, color: AppColors.failed),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: AppTypography.body125),
          const SizedBox(height: 4),
          Text(meta, style: AppTypography.mono12.copyWith(color: secondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (match, target) in rules)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeTokens.of(context).surface2,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: match,
                            style: AppTypography.mono12.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: ' → $target',
                            style: AppTypography.mono12.copyWith(color: secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectPreview extends StatelessWidget {
  const _ConnectPreview();

  static const _menuProfiles = [
    (OnboardingDemoData.everydayBrowsing, false),
    (OnboardingDemoData.officeNetwork, true),
    (OnboardingDemoData.officeViaHome, false),
    (OnboardingDemoData.homeWifi, false),
  ];

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;

    return TcInAnimation(
      scale: true,
      child: SizedBox(
        width: double.infinity,
        child: Center(
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TcPulseRing(
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.running.withValues(alpha: 0.14),
                          border: Border.all(color: AppColors.running, width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.power,
                              size: 24,
                              color: AppColors.running,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Connected',
                              style: AppTypography.body125.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.running,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'UPTIME 00:00:04',
                      style: AppTypography.mono12.copyWith(color: secondary),
                    ),
                  ],
                ),
                const SizedBox(width: 28),
                const _StatusBarMenuPreview(profiles: _menuProfiles),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// macOS menu-bar dropdown mock — overlaps the connect hero on step 4.
class _StatusBarMenuPreview extends StatelessWidget {
  const _StatusBarMenuPreview({required this.profiles});

  final List<(String, bool)> profiles;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondary = AppThemeTokens.of(context).textSecondary;
    const menuWidth = 272.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Container(
            width: menuWidth,
            decoration: BoxDecoration(
              color: AppColors.darkSurface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TunnelChain',
                              style: AppTypography.body135.copyWith(
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Connected · ${OnboardingDemoData.officeNetwork}',
                              style: AppTypography.body125.copyWith(color: secondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: true,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
                  child: Text(
                    'PROFILES',
                    style: AppTypography.sectionHeader.copyWith(color: secondary),
                  ),
                ),
                for (final (name, selected) in profiles)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text(
                            selected ? '✓' : '',
                            style: const TextStyle(
                              color: AppColors.running,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            name,
                            style: AppTypography.body14.copyWith(color: onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Positioned(
          top: -10,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF333333)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const _MenuBarPill(),
          ),
        ),
      ],
    );
  }
}

class _MenuBarPill extends StatelessWidget {
  const _MenuBarPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TunnelChainLogo(size: 14),
        ],
      ),
    );
  }
}
