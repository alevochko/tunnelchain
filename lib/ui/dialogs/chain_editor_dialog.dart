import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/protocol_kind.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';

/// Dialog to create or edit a chain (ordered hop list).
Future<void> showChainEditorDialog(
  BuildContext context, {
  Chain? existing,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _ChainEditorDialog(existing: existing),
  );
}

class _ChainEditorDialog extends ConsumerStatefulWidget {
  const _ChainEditorDialog({this.existing});

  final Chain? existing;

  @override
  ConsumerState<_ChainEditorDialog> createState() => _ChainEditorDialogState();
}

class _ChainEditorDialogState extends ConsumerState<_ChainEditorDialog> {
  late final TextEditingController _nameController;
  late List<String> _hopIds;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _hopIds = List.of(existing?.hopProfileIds ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profileCatalogProvider).profiles;
    final busy = ref.watch(tunnelCatalogProvider).busy;
    final profileMap = {for (final p in profiles) p.id: p};

    return AlertDialog(
      title: Text(widget.existing == null ? 'New chain' : 'Edit chain'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Office via Frankfurt',
              ),
              autofocus: widget.existing == null,
            ),
            const SizedBox(height: 16),
            Text('Hops (outer → inner)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (_hopIds.isEmpty)
              Text(
                'Add at least one profile. VLESS is usually the outer hop.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            for (var i = 0; i < _hopIds.length; i++) ...[
              const SizedBox(height: 6),
              _HopRow(
                index: i,
                profile: profileMap[_hopIds[i]],
                canMoveUp: i > 0,
                canMoveDown: i < _hopIds.length - 1,
                onMoveUp: () => _swap(i, i - 1),
                onMoveDown: () => _swap(i, i + 1),
                onRemove: () => setState(() => _hopIds.removeAt(i)),
              ),
            ],
            const SizedBox(height: 12),
            _AddHopMenu(
              profiles: _availableProfiles(profiles),
              onAdd: (id) => setState(() => _hopIds.add(id)),
            ),
            if (_localError != null) ...[
              const SizedBox(height: 12),
              Text(
                _localError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : () => _save(context),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  List<Profile> _availableProfiles(List<Profile> all) {
    final usedProtocols = <ProtocolKind>{};
    for (final id in _hopIds) {
      final p = all.where((x) => x.id == id).firstOrNull;
      if (p != null) usedProtocols.add(p.protocol);
    }
    return all.where((p) {
      if (_hopIds.contains(p.id)) return false;
      return !usedProtocols.contains(p.protocol);
    }).toList();
  }

  void _swap(int a, int b) {
    setState(() {
      final tmp = _hopIds[a];
      _hopIds[a] = _hopIds[b];
      _hopIds[b] = tmp;
    });
  }

  Future<void> _save(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _localError = 'Enter a chain name');
      return;
    }
    if (_hopIds.isEmpty) {
      setState(() => _localError = 'Add at least one hop');
      return;
    }

    final existing = widget.existing;
    final chain = Chain(
      id: existing?.id ?? 'chain-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      hopProfileIds: List.of(_hopIds),
    );

    final ok = await ref.read(tunnelCatalogProvider.notifier).saveChain(
      chain,
      previousId: existing?.id,
    );
    if (!context.mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _localError = ref.read(tunnelCatalogProvider).errorMessage;
      });
    }
  }
}

class _HopRow extends StatelessWidget {
  const _HopRow({
    required this.index,
    required this.profile,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final Profile? profile;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text('${index + 1}.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                profile?.name ?? 'Missing profile',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              onPressed: canMoveUp ? onMoveUp : null,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 18),
              onPressed: canMoveDown ? onMoveDown : null,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddHopMenu extends StatelessWidget {
  const _AddHopMenu({required this.profiles, required this.onAdd});

  final List<Profile> profiles;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return Text(
        'No more profiles to add (or import profiles first).',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return MenuAnchor(
      builder: (context, controller, child) {
        return OutlinedButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add hop'),
        );
      },
      menuChildren: [
        for (final p in profiles)
          MenuItemButton(
            onPressed: () => onAdd(p.id),
            child: Text('${p.name} (${p.protocol.name})'),
          ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
