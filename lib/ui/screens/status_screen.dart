import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/app/theme/app_spacing.dart';
import 'package:tunnel_chain/app/theme/app_typography.dart';
import 'package:tunnel_chain/app/theme/tunnel_status.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';
import 'package:tunnel_chain/state/connect_bundle.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:tunnel_chain/state/tunnel_session.dart';
import 'package:tunnel_chain/ui/chain_visualization.dart';
import 'package:tunnel_chain/ui/widgets/connection_hero.dart';
import 'package:tunnel_chain/ui/widgets/packet_layers_card.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';
import 'package:tunnel_chain/ui/widgets/status_profile_dropdown.dart';
import 'package:tunnel_chain/ui/widgets/verdict_card.dart';

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(tunnelSessionProvider);
    final notifier = ref.read(tunnelSessionProvider.notifier);
    final catalog = ref.watch(profileCatalogProvider);
    final tunnel = ref.watch(tunnelCatalogProvider);
    final bundle = ref.watch(connectBundleProvider);
    final plan = tunnel.plan;
    final activeProfile = plan.activeProfile;
    final routing = activeProfile?.routing ?? plan.effectiveRouting;
    final chainsById = {for (final c in plan.chains) c.id: c};
    final profileMap = {for (final p in catalog.profiles) p.id: p};
    final viz = const ChainVisualization();
    final routePaths = viz.routingPaths(
      routing: routing,
      chainsById: chainsById,
      profiles: profileMap,
      mtu: bundle?.tunnel.tunMtu ?? plan.wgMtu,
    );
    final displayChain = plan.primaryDisplayChain();
    final visibility = viz.visibility(chain: displayChain, profiles: profileMap);

    final errorText = _statusErrorText(session);

    return PlaceholderScreen(
      title: 'Status',
      subtitle: 'Connection state, external IP, traffic and active chain.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          ConnectionHeroCard(
            status: session.visualStatus,
            busy: session.busy,
            enabled: _heroEnabled(session),
            externalIp: session.externalIp ?? _placeholderIp(session),
            uptime: session.uptime,
            subtitle: _heroSubtitle(session, bundle, activeProfile),
            onPressed: () => _onHeroTap(session, notifier),
            footer: const SizedBox(
              width: 320,
              child: StatusProfileDropdown(),
            ),
          ),
          if (!session.helperAvailable) ...[
            const SizedBox(height: AppSpacing.xl),
            _HelperSetupCard(session: session, notifier: notifier),
          ],
          if (session.tunnelState == TunnelState.awaitingConfirm) ...[
            const SizedBox(height: AppSpacing.xl),
            _ConfirmBanner(session: session, notifier: notifier),
          ],
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.xl),
            VerdictCard(
              title: _statusErrorTitle(session),
              body: errorText,
              tone: VerdictTone.error,
              leading: const ErrorIcon(),
              actionLabel: session.canConnect ? 'Retry' : null,
              onAction: session.canConnect ? notifier.connect : null,
            ),
          ],
          if (session.tunnelState == TunnelState.resetting) ...[
            const SizedBox(height: AppSpacing.xl),
            const _ResetProgressCard(),
          ],
          const SizedBox(height: AppSpacing.xl),
          TrafficPanel(
            uploadBps: session.uploadBps,
            downloadBps: session.downloadBps,
            history: session.trafficHistory,
            live: session.trafficLive,
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final panels = [
                Expanded(
                  flex: 115,
                  child: PacketLayersPanel(routes: routePaths),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 100,
                  child: VisibilityPanel(rows: visibility),
                ),
              ];
              if (wide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: panels,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PacketLayersPanel(routes: routePaths),
                  const SizedBox(height: AppSpacing.xl),
                  VisibilityPanel(rows: visibility),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          ActiveRoutingPanel(
            activeChain: bundle?.activeChainLabel(
                  activeProfileName: activeProfile?.name,
                ) ??
                '—',
            defaultRoute: bundle?.defaultRouteLabel() ?? '—',
            overrideCount: routing.overrides.length,
          ),
        ],
        ),
      ),
    );
  }

  static String? _statusErrorText(TunnelUiState session) {
    final message = session.errorMessage?.trim();
    if (message != null && message.isNotEmpty) return message;
    if (session.tunnelState == TunnelState.failed) {
      return 'Connection failed. Check /tmp/tunnelchain-dev.log for details.';
    }
    if (session.tunnelState == TunnelState.degraded) {
      return 'Tunnel is up but connectivity looks degraded. '
          'Check inner hop and /tmp/tunnelchain-dev.log.';
    }
    return null;
  }

  static String _statusErrorTitle(TunnelUiState session) {
    return switch (session.tunnelState) {
      TunnelState.degraded => 'Degraded connection',
      _ => 'Connection failed',
    };
  }

  static String? _placeholderIp(TunnelUiState session) {
    if (session.tunnelState.isConnected ||
        session.tunnelState == TunnelState.awaitingConfirm) {
      return '—';
    }
    return null;
  }

  static bool _heroEnabled(TunnelUiState session) {
    if (session.busy) return false;
    return session.canConnect || session.canDisconnect;
  }

  static void _onHeroTap(TunnelUiState session, TunnelSessionNotifier notifier) {
    if (session.canDisconnect) {
      notifier.disconnect();
    } else if (session.canConnect) {
      notifier.connect();
    }
  }

  static String? _heroSubtitle(
    TunnelUiState session,
    ConnectBundle? bundle,
    ConnectionProfile? activeProfile,
  ) {
    final connectLabel = bundle?.activeChainLabel(
          activeProfileName: activeProfile?.name,
        ) ??
        activeProfile?.name;

    return switch (session.visualStatus) {
      TunnelVisualStatus.stopped => connectLabel == null
          ? 'Create a chain on Chains and pick a profile first'
          : null,
      TunnelVisualStatus.connecting => 'Validating config and starting core…',
      TunnelVisualStatus.awaitingConfirm =>
        'Confirm connectivity or wait for automatic rollback',
      TunnelVisualStatus.running =>
        connectLabel != null ? 'Connected via $connectLabel' : 'Tunnel is active',
      TunnelVisualStatus.degraded => 'Partial connectivity — check inner hop',
      TunnelVisualStatus.failed => 'Tap to retry',
      TunnelVisualStatus.resetting => 'Restoring network settings…',
    };
  }
}

class _HelperSetupCard extends StatelessWidget {
  const _HelperSetupCard({required this.session, required this.notifier});

  final TunnelUiState session;
  final TunnelSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privileged helper', style: AppTypography.cardTitle),
            const SizedBox(height: 6),
            Text(
              'Register the helper once, then approve in Login Items (or use dev mode with admin password).',
              style: AppTypography.body14.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: session.busy ? null : notifier.registerHelper,
                  child: const Text('Register helper'),
                ),
                OutlinedButton(
                  onPressed: session.busy ? null : notifier.openHelperSettings,
                  child: const Text('Open Login Items'),
                ),
                TextButton(
                  onPressed: session.busy ? null : notifier.refreshHelperStatus,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.session, required this.notifier});

  final TunnelUiState session;
  final TunnelSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final remaining = session.confirmCountdown;
    final mm = remaining == null ? '--' : (remaining.inMinutes % 60).toString();
    final ss = remaining == null
        ? '--'
        : (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return VerdictCard(
      title: 'Awaiting confirmation',
      body: 'If connectivity is broken, do nothing — everything will be restored automatically.',
      tone: VerdictTone.warning,
      leading: const WarningIcon(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rollback in $mm:$ss',
            style: AppTypography.mono145.copyWith(color: AppColors.degraded),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: session.busy ? null : notifier.confirm,
            child: const Text('Confirm — keep configuration'),
          ),
        ],
      ),
    );
  }
}

class _ResetProgressCard extends StatelessWidget {
  const _ResetProgressCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Resetting network settings…',
              style: AppTypography.cardTitle,
            ),
          ],
        ),
      ),
    );
  }
}
