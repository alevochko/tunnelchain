import 'dart:async';
import 'dart:convert';

import 'package:tunnel_chain/services/native_drag_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/domain/models/node_import_kind.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/ui/widgets/design_segmented_control.dart';

enum _ImportSource { url, clipboard, config }

Future<void> showNodeImportDialog(
  BuildContext context, {
  required NodeImportKind kind,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _NodeImportDialog(kind: kind),
  );
}

class _NodeImportDialog extends ConsumerStatefulWidget {
  const _NodeImportDialog({required this.kind});

  final NodeImportKind kind;

  @override
  ConsumerState<_NodeImportDialog> createState() => _NodeImportDialogState();
}

class _NodeImportDialogState extends ConsumerState<_NodeImportDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _urlController = TextEditingController();
  final _clipboardController = TextEditingController();
  final _configController = TextEditingController();
  bool _importing = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    NativeDragDrop.ensureInstalled();
    NativeDragDrop.onFileDropped = _handleNativeFileDrop;
    NativeDragDrop.onDragState = _handleNativeDragState;
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
    if (_tabs.index == _ImportSource.clipboard.index &&
        _clipboardController.text.isEmpty) {
      _loadClipboard(silent: true);
    }
    unawaited(
      NativeDragDrop.setListening(_tabs.index == _ImportSource.config.index),
    );
  }

  void _handleNativeFileDrop(String content) {
    if (!mounted || _tabs.index != _ImportSource.config.index) return;
    setState(() {
      _dragging = false;
      _configController.text = content;
    });
  }

  void _handleNativeDragState(bool dragging) {
    if (!mounted || _tabs.index != _ImportSource.config.index) return;
    setState(() => _dragging = dragging);
  }

  @override
  void dispose() {
    unawaited(NativeDragDrop.setListening(false));
    NativeDragDrop.onFileDropped = null;
    NativeDragDrop.onDragState = null;
    _tabs.dispose();
    _urlController.dispose();
    _clipboardController.dispose();
    _configController.dispose();
    super.dispose();
  }

  bool get _isVless => widget.kind == NodeImportKind.proxyVless;

  String get _title => _isVless ? 'Import proxy (VLESS)' : 'Import VPN (WireGuard)';

  String get _urlHint => _isVless
      ? 'vless://uuid@host:443?...'
      : 'https://… (subscription) or paste config in Config tab';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      actionsAlignment: MainAxisAlignment.end,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) => DesignSegmentedControl<_ImportSource>(
                segments: const [
                  DesignSegmentOption(
                    value: _ImportSource.url,
                    label: 'From URL',
                  ),
                  DesignSegmentOption(
                    value: _ImportSource.clipboard,
                    label: 'From clipboard',
                  ),
                  DesignSegmentOption(
                    value: _ImportSource.config,
                    label: 'From config',
                  ),
                ],
                selected: _ImportSource.values[_tabs.index],
                onChanged: _importing
                    ? null
                    : (source) => _tabs.animateTo(source.index),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildUrlTab(),
                  _buildClipboardTab(),
                  _buildConfigTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _importing ? null : _onPreview,
          child: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Preview'),
        ),
      ],
    );
  }

  Widget _buildUrlTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isVless
              ? 'Paste a vless:// share link.'
              : 'WireGuard configs are imported from .conf text or file upload.',
          style: AppTypography.body125.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TextField(
            controller: _urlController,
            autofocus: true,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: _urlHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClipboardTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste from clipboard or edit the text below.',
          style: AppTypography.body125.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadClipboard,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from clipboard'),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TextField(
            controller: _clipboardController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Clipboard content appears here',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTab() {
    final borderColor = _dragging
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickConfigFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_isVless ? 'Upload file' : 'Upload .conf'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _configController.clear(),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: borderColor,
                width: _dragging ? 2 : 1,
              ),
            ),
            child: TextField(
              controller: _configController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: _isVless
                    ? 'Drop a file here, or paste vless:// / sing-box or Xray JSON'
                    : 'Drop a .conf file here, or paste WireGuard config',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadClipboard({bool silent = false}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    setState(() => _clipboardController.text = text);
  }

  Future<void> _pickConfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: _isVless ? FileType.any : FileType.custom,
      allowedExtensions: _isVless ? null : ['conf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _configController.text = utf8.decode(bytes));
  }

  String? _payloadForCurrentTab() {
    return switch (_ImportSource.values[_tabs.index]) {
      _ImportSource.url => _urlController.text.trim(),
      _ImportSource.clipboard => _clipboardController.text.trim(),
      _ImportSource.config => _configController.text.trim(),
    };
  }

  Future<void> _onPreview() async {
    final payload = _payloadForCurrentTab();
    if (payload == null || payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to import')),
      );
      return;
    }

    if (_isVless) {
      await _previewVless(payload);
    } else {
      await _previewWireGuard(payload);
    }
  }

  Future<void> _previewVless(String payload) async {
    final trimmed = payload.trim();
    final looksLikeVless = trimmed.startsWith('vless://') ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('[');

    if (!looksLikeVless) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Paste a vless:// link or sing-box / Xray VLESS JSON',
            ),
          ),
        );
      }
      return;
    }

    final importService = ref.read(profileImportServiceProvider);
    try {
      final preview = importService.previewVlessPayload(trimmed);
      if (!mounted) return;
      await _confirmAndSave(
        preview: preview,
        onSave: () => ref
            .read(profileCatalogProvider.notifier)
            .importVless(trimmed),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _previewWireGuard(String content) async {
    if (content.startsWith('http://') || content.startsWith('https://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription URL import is not supported yet'),
          ),
        );
      }
      return;
    }

    final importService = ref.read(profileImportServiceProvider);
    try {
      final preview = importService.previewWireGuardConf(content);
      if (!mounted) return;
      await _confirmAndSave(
        preview: preview,
        onSave: () => ref
            .read(profileCatalogProvider.notifier)
            .importWireGuardConf(content),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _confirmAndSave({
    required Profile preview,
    required Future<dynamic> Function() onSave,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm import'),
        content: SingleChildScrollView(child: Text(_previewText(preview))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importing = true);
    try {
      final result = await onSave();
      if (!mounted) return;
      if (result != null) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  static String _previewText(Profile profile) {
    return switch (profile) {
      VlessProfile p => _vlessPreviewText(p),
      WireGuardProfile p =>
        'Name: ${p.name}\n'
        'Endpoint: ${p.endpointHost}:${p.endpointPort}\n'
        'Addresses: ${p.addresses.join(', ')}\n'
        'DNS: ${p.dnsServers.join(', ')}',
      _ => profile.name,
    };
  }

  static String _vlessPreviewText(VlessProfile p) {
    final transportDetail = switch (p.transport) {
      'grpc' when p.grpcServiceName.isNotEmpty => ' (${p.grpcServiceName})',
      'ws' || 'http' || 'httpupgrade' when p.transportPath.isNotEmpty =>
        ' (${p.transportPath})',
      _ => '',
    };

    final hostLine = p.transportHost.isNotEmpty
        ? '\nHost header: ${p.transportHost}'
        : '';

    return 'Name: ${p.name}\n'
        'Server: ${p.host}:${p.port}\n'
        'Transport: ${p.transport.toUpperCase()}$transportDetail\n'
        'Security: ${p.security}\n'
        'SNI: ${p.sni}$hostLine';
  }
}
