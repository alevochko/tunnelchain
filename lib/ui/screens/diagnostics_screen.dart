import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/domain/models/diagnostic_models.dart';
import 'package:tunnel_chain/state/diagnostics_session.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';
import 'package:tunnel_chain/ui/widgets/verdict_card.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(diagnosticsSessionProvider);
    final notifier = ref.read(diagnosticsSessionProvider.notifier);
    final report = session.report;

    return PlaceholderScreen(
      title: 'Diagnostics',
      subtitle: 'leakcheck, MTU, throughput, DNS and Doctor.',
      trailing: FilledButton.tonal(
        onPressed: session.busy ? null : notifier.runAll,
        child: session.busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Run Doctor'),
      ),
      child: ListView(
        children: [
          if (session.errorMessage != null) ...[
            VerdictCard(
              title: 'Diagnostics failed',
              body: session.errorMessage!,
              tone: VerdictTone.error,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (report == null && !session.busy)
            Text(
              'Press Run Doctor to scan proxy, DNS pin, routes and resolver health.',
              style: AppTypography.body14.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          if (report != null) ...[
            for (final check in report.checks) ...[
              _CheckCard(check: check),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const SectionOverline('Doctor findings', bottom: 0),
                const Spacer(),
                Text(
                  '${report.issueCount} issues',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final finding in report.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VerdictCard(
                  title: finding.title,
                  body: finding.detail,
                  tone: _toneForFinding(finding.severity),
                  actionLabel: finding.fixLabel,
                  onAction: finding.fixLabel == null
                      ? null
                      : () => notifier.resetNetwork(),
                ),
              ),
          ],
          if (session.resetSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset completed', style: AppTypography.cardTitle),
                    const SizedBox(height: 10),
                    for (final entry in session.resetSteps.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              entry.value ? '✓' : '…',
                              style: TextStyle(
                                color: entry.value
                                    ? AppColors.running
                                    : AppColors.stopped,
                                fontFamily: 'Menlo',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(entry.key),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          VerdictCard(
            title: 'Reset network settings',
            body:
                'Stops the core, clears system proxy, DNS pins, TUN routes and pf anchors. '
                'Use when the network stays broken after a crash.',
            actionLabel: session.busy ? null : 'Reset network settings…',
            onAction: session.busy ? null : notifier.resetNetwork,
            tone: VerdictTone.warning,
          ),
        ],
      ),
    );
  }

  static VerdictTone _toneForFinding(DoctorSeverity severity) {
    return switch (severity) {
      DoctorSeverity.info => VerdictTone.success,
      DoctorSeverity.warning => VerdictTone.warning,
      DoctorSeverity.error => VerdictTone.error,
      DoctorSeverity.fixed => VerdictTone.success,
    };
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.check});

  final DiagnosticCheck check;

  @override
  Widget build(BuildContext context) {
    final mark = switch (check.status) {
      DiagnosticStatus.ok => '✓',
      DiagnosticStatus.fail => '✗',
      DiagnosticStatus.warn => '!',
      DiagnosticStatus.running => '…',
      DiagnosticStatus.idle => '·',
    };

    return Card(
      child: ListTile(
        leading: Text(
          mark,
          style: TextStyle(
            fontFamily: 'Menlo',
            color: switch (check.status) {
              DiagnosticStatus.ok => AppColors.running,
              DiagnosticStatus.fail => AppColors.failed,
              DiagnosticStatus.warn => AppColors.degraded,
              _ => AppColors.stopped,
            },
          ),
        ),
        title: Text(check.title, style: AppTypography.cardTitle),
        subtitle: Text(check.detail, style: AppTypography.body125),
      ),
    );
  }
}
