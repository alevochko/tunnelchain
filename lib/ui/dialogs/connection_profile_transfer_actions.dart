import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/profile_secrets.dart';
import 'package:tunnel_chain/domain/serialization/connection_profile_bundle_codec.dart';
import 'package:tunnel_chain/services/connection_profile_transfer_service.dart';
import 'package:tunnel_chain/services/keychain_store.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:tunnel_chain/ui/dialogs/connection_profile_import_dialog.dart';
import 'package:tunnel_chain/ui/widgets/verdict_card.dart';

Future<void> exportConnectionProfiles(
  BuildContext context,
  WidgetRef ref, {
  List<ConnectionProfile>? profiles,
}) async {
  final plan = ref.read(tunnelCatalogProvider).plan;
  final nodes = ref.read(profileCatalogProvider).profiles;
  final keychain = ref.read(keychainStoreProvider);
  final service = ref.read(connectionProfileTransferServiceProvider);

  final draft = service.buildExportBundle(plan, nodes, profiles: profiles);
  if (draft.profiles.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to export')),
    );
    return;
  }

  final secretKeys = draft.nodes.expand(profileSecretKeys).toSet();
  final secrets = secretKeys.isEmpty
      ? const <String, String>{}
      : await keychain.getSecrets(secretKeys);
  final bundle = draft.copyWith(secrets: secrets);

  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final defaultName = profiles == null || profiles.length > 1
      ? 'tunnelchain-profiles-$stamp.json'
      : 'tunnelchain-profile-${profiles.first.id}-$stamp.json';

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export connection profiles',
    fileName: defaultName,
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (path == null || path.isEmpty) return;

  final file = File(path.endsWith('.json') ? path : '$path.json');
  await file.writeAsString(service.encodeBundle(bundle));

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Exported ${bundle.profiles.length} profile(s), '
        '${bundle.nodes.length} node(s), ${bundle.chains.length} chain(s)',
      ),
    ),
  );
}

Future<void> importConnectionProfiles(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Import connection profiles',
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;

  final bytes = result.files.single.bytes;
  if (bytes == null) {
    if (!context.mounted) return;
    _showImportError(context, 'Could not read the selected file.');
    return;
  }

  final service = ref.read(connectionProfileTransferServiceProvider);
  final plan = ref.read(tunnelCatalogProvider).plan;
  final existingNodes = ref.read(profileCatalogProvider).profiles;

  try {
    final bundle = service.decodeBundle(utf8.decode(bytes));
    final preview = service.buildImportPreview(bundle, plan, existingNodes);

    if (!context.mounted) return;
    final rows = await showConnectionProfileImportDialog(context, preview);
    if (rows == null || rows.isEmpty) return;

    final updatedPreview = ConnectionProfileImportPreview(
      profiles: rows,
      chains: preview.chains,
      nodes: preview.nodes,
      secrets: preview.secrets,
      nodesToAdd: preview.nodesToAdd,
    );
    final resolved = service.resolveImport(updatedPreview, plan);
    if (resolved.profiles.isEmpty &&
        resolved.chains.isEmpty &&
        resolved.nodes.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing selected to import')),
      );
      return;
    }

    final nodesOk = await ref
        .read(profileCatalogProvider.notifier)
        .mergeImportedBundle(resolved.nodes, resolved.secrets);
    if (!nodesOk) {
      if (!context.mounted) return;
      final message = ref.read(profileCatalogProvider).errorMessage;
      _showImportError(context, message ?? 'Failed to import nodes');
      return;
    }

    final ok = await ref
        .read(tunnelCatalogProvider.notifier)
        .mergeImportedBundle(resolved);
    if (!context.mounted) return;

    if (ok) {
      final parts = <String>[];
      if (resolved.profiles.isNotEmpty) {
        parts.add('${resolved.profiles.length} profile(s)');
      }
      if (resolved.nodes.isNotEmpty) {
        parts.add('${resolved.nodes.length} node(s)');
      }
      if (resolved.chains.isNotEmpty) {
        parts.add('${resolved.chains.length} chain(s)');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${parts.join(', ')}')),
      );
    } else {
      final message = ref.read(tunnelCatalogProvider).errorMessage;
      _showImportError(context, message ?? 'Import failed');
    }
  } on ConnectionProfileBundleFormatException catch (e) {
    if (!context.mounted) return;
    _showImportError(context, e.message);
  } catch (e) {
    if (!context.mounted) return;
    _showImportError(context, e.toString());
  }
}

void _showImportError(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import failed'),
      content: VerdictCard(
        title: 'Invalid profile file',
        body: message,
        tone: VerdictTone.error,
        leading: const ErrorIcon(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
