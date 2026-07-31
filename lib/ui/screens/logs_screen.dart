import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/services/core_controller.dart';
import 'package:tunnel_chain/services/diagnostic_report_exporter.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';
import 'package:tunnel_chain/state/diagnostics_session.dart';
import 'package:tunnel_chain/state/tunnel_session.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _lines = <String>[];
  final _searchController = TextEditingController();
  StreamSubscription<String>? _subscription;
  var _autoScroll = true;
  var _exporting = false;
  static const _maxLines = 500;

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenIfNeeded(TunnelUiState session) {
    final connected =
        session.tunnelState.isConnected ||
        session.tunnelState == TunnelState.awaitingConfirm;
    if (connected && _subscription == null) {
      final controller = ref.read(coreControllerProvider);
      _subscription = controller.clashApi.logLines().listen(
        (line) {
          setState(() {
            _lines.add(line);
            if (_lines.length > _maxLines) {
              _lines.removeRange(0, _lines.length - _maxLines);
            }
          });
        },
        onError: (_) {},
      );
    } else if (!connected && _subscription != null) {
      _subscription?.cancel();
      _subscription = null;
      setState(_lines.clear);
    }
  }

  List<String> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _lines;
    return _lines.where((l) => l.toLowerCase().contains(q)).toList();
  }

  Future<void> _exportDiagnosticReport() async {
    setState(() => _exporting = true);
    try {
      final exporter = ref.read(diagnosticReportExporterProvider);
      final session = ref.read(tunnelSessionProvider);
      final diagnostics = ref.read(diagnosticsSessionProvider).report;
      final path = await exporter.saveReport(
        DiagnosticExportContext(
          session: session,
          diagnostics: diagnostics,
          liveLogLines: List.of(_lines),
        ),
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diagnostic report saved to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(tunnelSessionProvider);
    _listenIfNeeded(session);
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'Menlo',
      height: 1.4,
    );

    return PlaceholderScreen(
      title: 'Logs',
      subtitle: 'Core log stream via Clash API.',
      trailing: OutlinedButton(
        onPressed: _exporting ? null : _exportDiagnosticReport,
        child: _exporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Export diagnostic report'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Auto-scroll'),
                selected: _autoScroll,
                onSelected: (v) => setState(() => _autoScroll = v),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        session.tunnelState.isConnected
                            ? 'Waiting for log lines…'
                            : 'No logs — core not running.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: SelectableText(_filtered[index], style: mono),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
