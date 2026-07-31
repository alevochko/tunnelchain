import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/app/theme/tunnel_status.dart';
import 'package:tunnel_chain/services/native_status_bar.dart';
import 'package:tunnel_chain/services/status_bar_service.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:tunnel_chain/state/tunnel_session.dart';
import 'package:window_manager/window_manager.dart';

/// Syncs app state to the native macOS status-bar menu.
class StatusBarHost extends ConsumerStatefulWidget {
  const StatusBarHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StatusBarHost> createState() => _StatusBarHostState();
}

class _StatusBarHostState extends ConsumerState<StatusBarHost>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    if (!Platform.isMacOS) return;

    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await StatusBarService.configureMainWindow();
      if (!mounted) return;
      await NativeStatusBar.install(_handleNativeAction);
      if (!mounted) return;
      _pushMenuState();
    });
  }

  @override
  void dispose() {
    if (Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      ref.listen(tunnelSessionProvider, (_, _) => _pushMenuState());
      ref.listen(tunnelCatalogProvider, (_, _) => _pushMenuState());
    }
    return widget.child;
  }

  Future<void> _handleNativeAction(String action, Object? arg) async {
    if (!mounted) return;

    final session = ref.read(tunnelSessionProvider.notifier);
    final catalog = ref.read(tunnelCatalogProvider.notifier);

    switch (action) {
      case 'selectProfile':
        final profileId = arg as String?;
        if (profileId == null) return;
        await catalog.setActiveProfile(profileId);
      case 'connect':
        await session.connect();
      case 'disconnect':
        await session.disconnect();
    }
    if (!mounted) return;
    _pushMenuState();
  }

  void _pushMenuState() {
    if (!Platform.isMacOS || !mounted) return;

    final session = ref.read(tunnelSessionProvider);
    final plan = ref.read(tunnelCatalogProvider).plan;
    final active = plan.activeProfile;
    final connected = session.tunnelState.isConnected ||
        session.tunnelState == TunnelState.awaitingConfirm;
    final connecting = session.busy &&
        (session.tunnelState == TunnelState.validating ||
            session.tunnelState == TunnelState.starting);

    final statusLine = _statusLine(session, active?.name);
    final connectSubtitle = _connectSubtitle(session, active?.name);

    unawaited(
      NativeStatusBar.pushState(
        StatusBarMenuState(
          profiles: [
            for (final profile in plan.profiles)
              (id: profile.id, name: profile.name),
          ],
          activeProfileId: active?.id,
          connected: connected,
          canConnect: session.canConnect,
          canDisconnect: session.canDisconnect,
          busy: session.busy,
          switchOn: connected || connecting,
          switchEnabled: !session.busy &&
              (session.canConnect || session.canDisconnect),
          statusLine: statusLine,
          connectSubtitle: connectSubtitle,
        ),
      ),
    );
  }

  static String _statusLine(TunnelUiState session, String? profileName) {
    if (session.busy && session.tunnelState == TunnelState.validating) {
      return 'Connecting…';
    }
    if (session.tunnelState.isConnected) {
      final name = profileName ?? session.activeChainName;
      return name != null ? 'Connected · $name' : 'Connected';
    }
    if (session.tunnelState == TunnelState.awaitingConfirm) {
      return 'Awaiting confirmation';
    }
    final label = mapTunnelState(session.tunnelState).label;
    return profileName != null ? '$label · $profileName' : label;
  }

  static String _connectSubtitle(TunnelUiState session, String? profileName) {
    if (session.busy &&
        (session.tunnelState == TunnelState.validating ||
            session.tunnelState == TunnelState.starting)) {
      return 'Connecting…';
    }
    if (session.tunnelState.isConnected) {
      final name = profileName ?? session.activeChainName;
      return name != null ? 'Connected · $name' : 'Connected';
    }
    if (session.tunnelState == TunnelState.awaitingConfirm) {
      return 'Awaiting confirmation';
    }
    if (session.tunnelState == TunnelState.failed) {
      return 'Connection failed';
    }
    if (session.tunnelState == TunnelState.resetting) {
      return 'Disconnecting…';
    }
    return 'Not Connected';
  }

  @override
  void onWindowClose() {
    unawaited(StatusBarService.hideMainWindow());
  }
}
