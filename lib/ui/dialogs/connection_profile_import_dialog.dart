import 'package:flutter/material.dart';
import 'package:tunnel_chain/services/connection_profile_transfer_service.dart';
import 'package:tunnel_chain/ui/widgets/design_segmented_control.dart';

Future<List<ProfileImportRow>?> showConnectionProfileImportDialog(
  BuildContext context,
  ConnectionProfileImportPreview preview,
) {
  return showDialog<List<ProfileImportRow>>(
    context: context,
    builder: (ctx) => _ConnectionProfileImportDialog(preview: preview),
  );
}

class _ConnectionProfileImportDialog extends StatefulWidget {
  const _ConnectionProfileImportDialog({required this.preview});

  final ConnectionProfileImportPreview preview;

  @override
  State<_ConnectionProfileImportDialog> createState() =>
      _ConnectionProfileImportDialogState();
}

class _ConnectionProfileImportDialogState
    extends State<_ConnectionProfileImportDialog> {
  late final List<ProfileImportRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.preview.profiles
        .map(
          (row) => ProfileImportRow(
            profile: row.profile,
            hasIdConflict: row.hasIdConflict,
            action: row.action,
            selected: row.selected,
          ),
        )
        .toList();
  }

  int get _selectedCount => _rows.where((r) => r.selected).length;

  @override
  Widget build(BuildContext context) {
    final chainCount = widget.preview.chains.length;
    final nodeCount = widget.preview.nodesToAdd;

    return AlertDialog(
      title: const Text('Import profiles'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                if (nodeCount > 0) '$nodeCount ${nodeCount == 1 ? 'node' : 'nodes'}',
                '$chainCount ${chainCount == 1 ? 'chain' : 'chains'}',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _ProfileImportTile(
                  row: _rows[index],
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedCount == 0
              ? null
              : () => Navigator.pop(context, _rows),
          child: Text('Import ($_selectedCount)'),
        ),
      ],
    );
  }
}

class _ProfileImportTile extends StatelessWidget {
  const _ProfileImportTile({required this.row, required this.onChanged});

  final ProfileImportRow row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: row.selected,
            onChanged: (value) {
              row.selected = value ?? false;
              onChanged();
            },
            title: Text(row.profile.name),
            subtitle: Text(
              row.profile.isSimpleFullTunnel
                  ? 'Full tunnel'
                  : '${row.profile.routing.overrides.length} rules',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (row.hasIdConflict && row.selected) ...[
            const SizedBox(height: 4),
            DesignSegmentedControl<ImportConflictAction>(
              segments: const [
                DesignSegmentOption(
                  value: ImportConflictAction.rename,
                  label: 'Rename',
                ),
                DesignSegmentOption(
                  value: ImportConflictAction.replace,
                  label: 'Replace',
                ),
                DesignSegmentOption(
                  value: ImportConflictAction.skip,
                  label: 'Skip',
                  icon: Icons.check_rounded,
                ),
              ],
              selected: row.action,
              onChanged: (action) {
                row.action = action;
                onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}
