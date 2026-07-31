import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:tunnel_chain/ui/dialogs/chain_editor_dialog.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';

class ProxiesScreen extends ConsumerWidget {
  const ProxiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunnel = ref.watch(tunnelCatalogProvider);
    final profiles = ref.watch(profileCatalogProvider).profiles;
    final profileMap = {for (final p in profiles) p.id: p};
    final chains = tunnel.plan.chains;
    final notifier = ref.read(tunnelCatalogProvider.notifier);

    return PlaceholderScreen(
      title: 'Chains',
      subtitle: 'Compose VPN/proxy nodes into hop sequences.',
      trailing: OutlinedButton(
        onPressed: tunnel.busy
            ? null
            : () => showChainEditorDialog(context),
        child: const Text('New chain'),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (tunnel.errorMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(tunnel.errorMessage!),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (chains.isEmpty)
              Text(
                'No chains yet. Import nodes, then create a chain.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            for (final chain in chains) ...[
              _ChainCard(
                chain: chain,
                hops: chain.hopProfileIds
                    .map((id) => profileMap[id]?.name ?? 'missing')
                    .join(' → '),
                busy: tunnel.busy,
                onEdit: () => showChainEditorDialog(context, existing: chain),
                onDelete: () => _confirmDelete(context, notifier, chain),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TunnelCatalogNotifier notifier,
    Chain chain,
  ) async {
    final referenced = notifier.isChainReferenced(chain.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chain?'),
        content: Text(
          referenced
              ? '"${chain.name}" is used in a profile. Deleting it removes related profiles and updates routing.'
              : 'Remove "${chain.name}"?',
        ),
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
      await notifier.deleteChain(chain.id);
    }
  }
}

class _ChainCard extends StatelessWidget {
  const _ChainCard({
    required this.chain,
    required this.hops,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final Chain chain;
  final String hops;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chain.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(hops, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HopChip(count: chain.hopProfileIds.length),
                const Spacer(),
                OutlinedButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: busy ? null : onDelete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HopChip extends StatelessWidget {
  const _HopChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count ${count == 1 ? 'hop' : 'hops'}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
