import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/domain/models/node_import_kind.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/ui/dialogs/node_import_dialog.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(profileCatalogProvider);
    final notifier = ref.read(profileCatalogProvider.notifier);

    return PlaceholderScreen(
      title: 'Nodes',
      subtitle: 'Import proxy and VPN endpoints for use in chains.',
      child: catalog.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (catalog.errorMessage != null) ...[
                    Text(
                      catalog.errorMessage!,
                      style: AppTypography.body14.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (catalog.lastImportWarnings.isNotEmpty) ...[
                    for (final warning in catalog.lastImportWarnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          warning,
                          style: AppTypography.body125.copyWith(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  const SectionOverline('Add proxy', bottom: 10),
                  _NodeKindSelector<ProxyNodeKind>(
                    values: ProxyNodeKind.values,
                    label: (k) => k.label,
                    supported: (k) => k.supported,
                    busy: catalog.busy,
                    onSelected: (_) => showNodeImportDialog(
                      context,
                      kind: NodeImportKind.proxyVless,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionOverline('Add VPN', bottom: 10),
                  _NodeKindSelector<VpnNodeKind>(
                    values: VpnNodeKind.values,
                    label: (k) => k.label,
                    supported: (k) => k.supported,
                    busy: catalog.busy,
                    onSelected: (_) => showNodeImportDialog(
                      context,
                      kind: NodeImportKind.vpnWireGuard,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionOverline('Saved nodes', bottom: 12),
                  if (catalog.profiles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No nodes yet — pick a type above to import.',
                        style: AppTypography.body14.copyWith(
                          color: AppThemeTokens.of(context).textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final profile in catalog.profiles) ...[
                      _SavedNodeCard(
                        profile: profile,
                        busy: catalog.busy,
                        onDelete: () => notifier.deleteProfile(profile.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }

  static String _kindLabel(Profile profile) {
    return switch (profile) {
      VlessProfile() => 'VLESS',
      WireGuardProfile() => 'WIREGUARD',
      _ => profile.kind.name.toUpperCase(),
    };
  }

  static String _endpointSummary(Profile profile) {
    return switch (profile) {
      VlessProfile p => '${p.host}:${p.port}',
      WireGuardProfile p => '${p.endpointHost}:${p.endpointPort}',
      _ => '',
    };
  }

  static String _addedLabel(DateTime createdAt) {
    final days = DateTime.now().difference(createdAt).inDays;
    if (days == 0) return 'Added today';
    if (days == 1) return 'Added yesterday';
    return 'Added $days days ago';
  }
}

class _SavedNodeCard extends StatelessWidget {
  const _SavedNodeCard({
    required this.profile,
    required this.busy,
    required this.onDelete,
  });

  final Profile profile;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    final endpoint = ProfilesScreen._endpointSummary(profile);
    final added = ProfilesScreen._addedLabel(profile.createdAt);
    final metadata = endpoint.isEmpty ? added : '$endpoint · $added';
    final wg = profile is WireGuardProfile ? profile as WireGuardProfile : null;
    final showAwg = wg?.obfuscation?.isNonTrivial() == true;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTypography.body14.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  metadata,
                  style: AppTypography.body125.copyWith(color: secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ProtocolBadge(label: ProfilesScreen._kindLabel(profile)),
          if (showAwg) ...[
            const SizedBox(width: 8),
            const _ProtocolBadge(label: 'AWG', warning: true),
          ],
          const SizedBox(width: 4),
          ActionCursor(
            enabled: !busy,
            child: IconButton(
              tooltip: 'Delete',
              onPressed: busy ? null : onDelete,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeKindSelector<T> extends StatelessWidget {
  const _NodeKindSelector({
    required this.values,
    required this.label,
    required this.supported,
    required this.busy,
    required this.onSelected,
  });

  final List<T> values;
  final String Function(T) label;
  final bool Function(T) supported;
  final bool busy;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          _KindOptionChip(
            label: label(value),
            active: supported(value),
            enabled: !busy && supported(value),
            onTap: supported(value) ? () => onSelected(value) : null,
          ),
      ],
    );
  }
}

class _KindOptionChip extends StatelessWidget {
  const _KindOptionChip({
    required this.label,
    required this.active,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final fg = active ? onSurface : tokens.textSecondary;
    final bg = active ? Colors.transparent : tokens.surface2;
    final border = active
        ? Border.all(color: onSurface, width: 1)
        : Border.all(color: Colors.transparent, width: 1);

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.body125.copyWith(
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: fg,
        ),
      ),
    );

    if (!enabled || onTap == null) {
      return Tooltip(
        message: active ? label : '$label — coming soon',
        child: child,
      );
    }

    return Tooltip(
      message: 'Import $label',
      child: ActionInkWell(
        enabled: enabled,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  const _ProtocolBadge({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = brightness == Brightness.dark
        ? AppColors.accent
        : AppColors.accentLight;
    final color = warning
        ? (brightness == Brightness.dark
            ? AppColors.degraded
            : AppColors.degradedLight)
        : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: warning
            ? AppColors.warningBg(brightness)
            : AppColors.accentBg(brightness),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.mono12.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
