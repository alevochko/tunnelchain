import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_theme.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';

/// Active profile picker for the Status hero card.
class StatusProfileDropdown extends ConsumerWidget {
  const StatusProfileDropdown({super.key});

  static const _triggerHeight = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunnel = ref.watch(tunnelCatalogProvider);
    final notifier = ref.read(tunnelCatalogProvider.notifier);
    final plan = tunnel.plan;
    final profiles = plan.profiles;
    final active = plan.activeProfile;
    final border = Theme.of(context).dividerColor;
    final tokens = AppThemeTokens.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final enabled = !tunnel.busy && profiles.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth;

        return MenuAnchor(
          crossAxisUnconstrained: false,
          alignmentOffset: const Offset(0, 6),
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 6),
            ),
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(menuWidth, 360)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                side: BorderSide(color: border),
              ),
            ),
            backgroundColor: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.surface,
            ),
            elevation: const WidgetStatePropertyAll(8),
          ),
          builder: (context, controller, _) {
            return ActionInkWell(
              onTap: enabled
                  ? () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              child: Container(
                width: menuWidth,
                height: _triggerHeight,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.buttonPaddingH,
                  0,
                  8,
                  0,
                ),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'PROFILE',
                      style: AppTypography.sectionHeader.copyWith(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: menuWidth * 0.62,
                          ),
                          child: Text(
                            active?.name ?? 'No profile',
                            style: AppTypography.button.copyWith(
                              color: onSurface,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          size: 16,
                          color: enabled
                              ? tokens.textSecondary
                              : tokens.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          menuChildren: [
            for (final profile in profiles)
              SizedBox(
                width: menuWidth,
                child: MenuItemButton(
                  onPressed: tunnel.busy
                      ? null
                      : () => notifier.setActiveProfile(profile.id),
                  style: actionMouseCursor(
                    ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(
                        Size(
                          menuWidth,
                          profile.routing.overrides.isEmpty ? 40 : 52,
                        ),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  child: _ProfileMenuRow(
                    profile: profile,
                    selected: profile.id == active?.id,
                  ),
                ),
              ),
            if (profiles.isEmpty)
              SizedBox(
                width: menuWidth,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text('Create a profile on the Profiles tab'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.profile,
    required this.selected,
  });

  final ConnectionProfile profile;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final secondary = AppThemeTokens.of(context).textSecondary;
    final running = Theme.of(context).brightness == Brightness.dark
        ? AppColors.running
        : AppColors.runningLight;
    final hasRules = !profile.isSimpleFullTunnel &&
        profile.routing.overrides.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: hasRules ? 36 : 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: selected
                ? Icon(Icons.check, size: 14, color: running)
                : null,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: AppTypography.body14.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasRules)
                Text(
                  'Split · ${profile.routing.overrides.length} rules',
                  style: AppTypography.body125.copyWith(
                    color: secondary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
