import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:tunnel_chain/ui/dialogs/connection_profile_editor_dialog.dart';
import 'package:tunnel_chain/ui/dialogs/connection_profile_transfer_actions.dart';
import 'package:tunnel_chain/ui/widgets/action_cursor.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';

class RoutingScreen extends ConsumerWidget {
  const RoutingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunnel = ref.watch(tunnelCatalogProvider);
    final plan = tunnel.plan;
    final activeId = plan.activeProfile?.id;
    final chainById = {for (final c in plan.chains) c.id: c};
    final notifier = ref.read(tunnelCatalogProvider.notifier);

    return PlaceholderScreen(
      title: 'Profiles',
      subtitle:
          'Routing and DNS per profile — tap to activate, edit to configure rules.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: tunnel.busy
                ? null
                : () => importConnectionProfiles(context, ref),
            icon: const Icon(Icons.upload_outlined, size: 18),
            label: const Text('Import'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: tunnel.busy || plan.profiles.isEmpty
                ? null
                : () => exportConnectionProfiles(context, ref),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: tunnel.busy
                ? null
                : () => showConnectionProfileEditorDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New profile'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tunnel.errorMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(tunnel.errorMessage!),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SectionOverline('Profiles'),
            const SizedBox(height: 8),
            if (plan.profiles.isEmpty)
              Text(
                'No profiles yet. A simple profile routes all traffic through '
                'one chain; split routing sends different destinations to '
                'different chains.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            for (final profile in plan.profiles) ...[
              _ProfileCard(
                profile: profile,
                chainById: chainById,
                isActive: profile.id == activeId,
                busy: tunnel.busy,
                onTap: () async {
                  if (profile.id == activeId) return;
                  await notifier.setActiveProfile(profile.id);
                },
                onEdit: () => showConnectionProfileEditorDialog(
                  context,
                  existing: profile,
                ),
                onClone: () => showConnectionProfileEditorDialog(
                  context,
                  cloneFrom: profile,
                ),
                onExport: () => exportConnectionProfiles(
                  context,
                  ref,
                  profiles: [profile],
                ),
                onDelete: () => _confirmDeleteProfile(context, notifier, profile),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProfile(
    BuildContext context,
    TunnelCatalogNotifier notifier,
    ConnectionProfile profile,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Remove "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await notifier.deleteProfile(profile.id);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.chainById,
    required this.isActive,
    required this.busy,
    required this.onTap,
    required this.onEdit,
    required this.onClone,
    required this.onExport,
    required this.onDelete,
  });

  final ConnectionProfile profile;
  final Map<String, Chain> chainById;
  final bool isActive;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final summary = _routingSummary(profile, chainById);
    final ruleCount = profile.routing.overrides.length;
    final chainNames = profile.referencedChainIds()
        .map((id) => chainById[id]?.name ?? id)
        .toList();

    return Material(
      color: Theme.of(context).cardColor,
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.running : Theme.of(context).dividerColor,
          width: isActive ? 2 : 1,
        ),
      ),
      child: ActionInkWell(
        onTap: busy ? null : onTap,
        enabled: !busy,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'Active',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.running,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Export profile',
                    onPressed: busy ? null : onExport,
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Clone profile',
                    onPressed: busy ? null : onClone,
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Edit routing & DNS',
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: busy ? null : onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!profile.isSimpleFullTunnel && ruleCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$ruleCount ${ruleCount == 1 ? 'rule' : 'rules'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (chainNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Chains: ${chainNames.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'DNS: ${profile.dns.publicResolver}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Menlo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _routingSummary(
    ConnectionProfile profile,
    Map<String, Chain> chainById,
  ) {
    if (profile.isSimpleFullTunnel) {
      final chainName =
          chainById[profile.simpleChainId]?.name ?? profile.simpleChainId ?? '—';
      return 'Full tunnel → $chainName';
    }

    final defaultLabel = profile.routing.defaultTarget.isDirect
        ? 'Direct'
        : chainById[profile.routing.defaultTarget.chainId]?.name ?? '—';

    if (profile.routing.overrides.isEmpty) {
      return 'Default: $defaultLabel';
    }

    return 'Split routing · default $defaultLabel';
  }
}
