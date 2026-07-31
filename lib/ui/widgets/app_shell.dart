import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/state/sidebar_state_provider.dart';
import 'package:tunnel_chain/state/theme_mode_provider.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';
import 'package:tunnel_chain/ui/widgets/nav_icon.dart';
import 'package:tunnel_chain/ui/widgets/tunnel_chain_logo.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _NavDestination(
      NavIconKind.status,
      'Status',
      'Connection, IP and traffic',
    ),
    _NavDestination(
      NavIconKind.routing,
      'Profiles',
      'Routing and DNS rules',
    ),
    _NavDestination(
      NavIconKind.proxies,
      'Chains',
      'Combine nodes into hops',
    ),
    _NavDestination(
      NavIconKind.profiles,
      'Nodes',
      'Import VPN and proxy servers',
    ),
    _NavDestination(
      NavIconKind.diagnostics,
      'Diagnostics',
      'Leak check, MTU and DNS',
    ),
    _NavDestination(
      NavIconKind.logs,
      'Logs',
      'sing-box log stream',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = navigationShell.currentIndex;
    final themeMode = ref.watch(themeModeProvider);
    final expanded = ref.watch(sidebarExpandedProvider);
    final isDark = themeMode == ThemeMode.dark;
    final sidebarWidth = expanded
        ? AppSpacing.sidebarWidth
        : AppSpacing.sidebarWidthCollapsed;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: sidebarWidth,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  expanded ? AppSpacing.sidebarPaddingH : 6,
                  AppSpacing.sidebarPaddingTop,
                  expanded ? AppSpacing.sidebarPaddingH : 6,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SidebarHeader(expanded: expanded),
                    SizedBox(height: expanded ? 12 : 10),
                    _ThemeToggleRow(
                      expanded: expanded,
                      themeMode: themeMode,
                      onDark: () =>
                          ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
                      onLight: () =>
                          ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
                      onToggle: () => ref.read(themeModeProvider.notifier).toggle(),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          for (var i = 0; i < _destinations.length; i++)
                            _SidebarNavItem(
                              label: _destinations[i].label,
                              subtitle: _destinations[i].subtitle,
                              icon: _destinations[i].icon,
                              selected: selected == i,
                              collapsed: !expanded,
                              onTap: () => _onNavTap(i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SidebarToggleButton(
                      expanded: expanded,
                      onPressed: () =>
                          ref.read(sidebarExpandedProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return const Center(child: TunnelChainLogo());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
      child: Row(
        children: [
          const TunnelChainLogo(),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'TunnelChain',
              style: AppTypography.brandTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final fg = tokens.textSecondary;

    return ActionCursor(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          mouseCursor: SystemMouseCursors.click,
          child: SizedBox(
            height: AppSpacing.navItemHeight,
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (expanded) const SizedBox(width: 9),
                Icon(
                  expanded
                      ? Icons.keyboard_double_arrow_left_rounded
                      : Icons.keyboard_double_arrow_right_rounded,
                  size: 18,
                  color: fg,
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Collapse',
                    style: AppTypography.navItem.copyWith(color: fg),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow({
    required this.expanded,
    required this.themeMode,
    required this.onDark,
    required this.onLight,
    required this.onToggle,
  });

  final bool expanded;
  final ThemeMode themeMode;
  final VoidCallback onDark;
  final VoidCallback onLight;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return _CollapsedThemeButton(themeMode: themeMode, onToggle: onToggle);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _ThemeToggleSegment(
              label: 'Dark',
              selected: themeMode == ThemeMode.dark,
              onTap: onDark,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(-1, 0),
              child: _ThemeToggleSegment(
                label: 'Light',
                selected: themeMode == ThemeMode.light,
                onTap: onLight,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedThemeButton extends StatelessWidget {
  const _CollapsedThemeButton({
    required this.themeMode,
    required this.onToggle,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isDark = themeMode == ThemeMode.dark;

    return ActionCursor(
      child: Material(
        color: tokens.accentBg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          mouseCursor: SystemMouseCursors.click,
          child: SizedBox(
            height: AppSpacing.navItemHeight,
            child: Center(
              child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 17,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleSegment extends StatelessWidget {
  const _ThemeToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.borderRadius,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final fg = selected
        ? Theme.of(context).colorScheme.onSurface
        : AppThemeTokens.of(context).textSecondary;
    final bg = selected ? AppThemeTokens.of(context).accentBg : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: borderRadius,
      child: ActionCursor(
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: borderRadius,
            ),
            child: Text(
              label,
              style: AppTypography.body125.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.icon, this.label, this.subtitle);

  final NavIconKind icon;
  final String label;
  final String subtitle;
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final NavIconKind icon;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final fg = selected
        ? Theme.of(context).colorScheme.onSurface
        : tokens.textSecondary;
    final subtitleColor = selected
        ? tokens.textSecondary
        : tokens.textSecondary.withValues(alpha: 0.72);
    final bg = selected ? tokens.accentBg : Colors.transparent;

    final item = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ActionCursor(
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            mouseCursor: SystemMouseCursors.click,
            child: collapsed
                ? SizedBox(
                    height: AppSpacing.navItemHeight,
                    child: Center(child: NavIcon(icon, color: fg)),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: NavIcon(icon, color: fg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: AppTypography.navItem.copyWith(color: fg),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: AppTypography.body125.copyWith(
                                  color: subtitleColor,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );

    if (!collapsed) return item;

    return Tooltip(
      message: '$label — $subtitle',
      waitDuration: const Duration(milliseconds: 350),
      child: item,
    );
  }
}
