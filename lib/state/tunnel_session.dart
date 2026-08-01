import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/services/system_dns_policy.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';
import 'package:tunnel_chain/services/connect_safety_policy.dart';
import 'package:tunnel_chain/services/core_controller.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';
import 'package:tunnel_chain/app/theme/tunnel_status.dart';
import 'package:tunnel_chain/domain/serialization/tunnel_plan_codec.dart';
import 'package:tunnel_chain/state/connect_bundle.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';

class TunnelUiState {
  const TunnelUiState({
    this.tunnelState = TunnelState.stopped,
    this.helperStatus = 'notRegistered',
    this.helperAvailable = false,
    this.helperStatusLabel = 'Not registered',
    this.busy = false,
    this.errorMessage,
    this.resetSteps = const {},
    this.awaitingConfirmSince,
    this.safetyTimeoutSec = 300,
    this.uploadBps = 0,
    this.downloadBps = 0,
    this.trafficHistory = const <TrafficSample>[],
    this.trafficLive = false,
    this.externalIp,
    this.activeChainName,
    this.layerLabels = const [],
    this.connectedSince,
    this.totalUploadBytes = 0,
    this.totalDownloadBytes = 0,
  });

  final TunnelState tunnelState;
  final String helperStatus;
  final bool helperAvailable;
  final String helperStatusLabel;
  final bool busy;
  final String? errorMessage;
  final Map<String, bool> resetSteps;
  final DateTime? awaitingConfirmSince;
  final int safetyTimeoutSec;
  final int uploadBps;
  final int downloadBps;
  final List<TrafficSample> trafficHistory;
  final bool trafficLive;
  final String? externalIp;
  final String? activeChainName;
  final List<String> layerLabels;
  final DateTime? connectedSince;
  final int totalUploadBytes;
  final int totalDownloadBytes;

  Duration? get uptime {
    final since = connectedSince;
    if (since == null) return null;
    if (!tunnelState.isConnected &&
        tunnelState != TunnelState.awaitingConfirm) {
      return null;
    }
    return DateTime.now().difference(since);
  }

  TunnelVisualStatus get visualStatus => mapTunnelState(tunnelState);

  Duration? get confirmCountdown {
    final since = awaitingConfirmSince;
    if (since == null || tunnelState != TunnelState.awaitingConfirm) {
      return null;
    }
    final remaining =
        safetyTimeoutSec - DateTime.now().difference(since).inSeconds;
    return Duration(seconds: remaining.clamp(0, safetyTimeoutSec));
  }

  bool get canConnect =>
      !busy &&
      !tunnelState.isLive &&
      tunnelState != TunnelState.resetting &&
      tunnelState != TunnelState.validating &&
      tunnelState != TunnelState.starting &&
      tunnelState != TunnelState.awaitingConfirm;

  bool get canDisconnect =>
      !busy &&
      (tunnelState.isLive ||
          tunnelState == TunnelState.awaitingConfirm ||
          tunnelState == TunnelState.resetting);

  TunnelUiState copyWith({
    TunnelState? tunnelState,
    String? helperStatus,
    bool? helperAvailable,
    String? helperStatusLabel,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    Map<String, bool>? resetSteps,
    DateTime? awaitingConfirmSince,
    bool clearAwaiting = false,
    int? safetyTimeoutSec,
    int? uploadBps,
    int? downloadBps,
    List<TrafficSample>? trafficHistory,
    bool? trafficLive,
    bool clearTraffic = false,
    String? externalIp,
    bool clearExternalIp = false,
    String? activeChainName,
    List<String>? layerLabels,
    DateTime? connectedSince,
    bool clearConnectedSince = false,
    int? totalUploadBytes,
    int? totalDownloadBytes,
  }) {
    return TunnelUiState(
      tunnelState: tunnelState ?? this.tunnelState,
      helperStatus: helperStatus ?? this.helperStatus,
      helperAvailable: helperAvailable ?? this.helperAvailable,
      helperStatusLabel: helperStatusLabel ?? this.helperStatusLabel,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resetSteps: resetSteps ?? this.resetSteps,
      awaitingConfirmSince: clearAwaiting
          ? null
          : (awaitingConfirmSince ?? this.awaitingConfirmSince),
      safetyTimeoutSec: safetyTimeoutSec ?? this.safetyTimeoutSec,
      uploadBps: clearTraffic ? 0 : (uploadBps ?? this.uploadBps),
      downloadBps: clearTraffic ? 0 : (downloadBps ?? this.downloadBps),
      trafficHistory: clearTraffic
          ? const <TrafficSample>[]
          : (trafficHistory ?? this.trafficHistory ?? const <TrafficSample>[]),
      trafficLive: clearTraffic ? false : (trafficLive ?? this.trafficLive),
      externalIp: clearExternalIp ? null : (externalIp ?? this.externalIp),
      activeChainName: activeChainName ?? this.activeChainName,
      layerLabels: layerLabels ?? this.layerLabels,
      connectedSince: clearConnectedSince
          ? null
          : (connectedSince ?? this.connectedSince),
      totalUploadBytes:
          clearTraffic ? 0 : (totalUploadBytes ?? this.totalUploadBytes),
      totalDownloadBytes:
          clearTraffic ? 0 : (totalDownloadBytes ?? this.totalDownloadBytes),
    );
  }
}

class TunnelSessionNotifier extends Notifier<TunnelUiState> {
  StreamSubscription<TunnelState>? _stateSub;
  StreamSubscription<TrafficSample>? _trafficSub;
  Timer? _liveTicker;
  String? _activeProfileConfigKey;

  static const _planCodec = TunnelPlanCodec();

  CoreController get _controller => ref.read(coreControllerProvider);

  @override
  TunnelUiState build() {
    ref.onDispose(_dispose);
    _stateSub = _controller.states.listen(_onTunnelState);
    unawaited(_refreshHelperStatus());

    ref.listen(tunnelCatalogProvider, (previous, next) {
      if (next.loading) return;

      final active = next.plan.activeProfile;
      final nextKey = active == null
          ? null
          : _planCodec.profileConnectConfigKey(active);
      final prevActive = previous?.loading == false
          ? previous?.plan.activeProfile
          : null;
      final prevKey = prevActive == null
          ? _activeProfileConfigKey
          : _planCodec.profileConnectConfigKey(prevActive);

      final activeProfileEdited =
          active != null &&
          prevActive?.id == active.id &&
          prevKey != null &&
          nextKey != null &&
          prevKey != nextKey;

      final profileSwitched =
          active != null &&
          prevActive != null &&
          prevActive.id != active.id;

      _activeProfileConfigKey = nextKey;

      _syncDisplayFromBundle();

      if ((profileSwitched || activeProfileEdited) && _isLive) {
        unawaited(reconnectIfConnected());
      }
    });

    ref.listen(connectBundleProvider, (_, _) => _syncDisplayFromBundle());

    final bundle = ref.read(connectBundleProvider);
    final plan = ref.read(tunnelCatalogProvider).plan;
    final active = plan.activeProfile;
    _activeProfileConfigKey = active == null
        ? null
        : _planCodec.profileConnectConfigKey(active);

    return TunnelUiState(
      activeChainName: bundle?.activeChainLabel(activeProfileName: active?.name),
      layerLabels: bundle?.layerLabelsForPlan(plan) ??
          const ['Application', 'Egress'],
    );
  }

  void _syncDisplayFromBundle() {
    final bundle = ref.read(connectBundleProvider);
    final plan = ref.read(tunnelCatalogProvider).plan;
    final profile = plan.activeProfile;
    if (bundle == null) {
      state = state.copyWith(
        activeChainName: profile?.name,
        layerLabels: const ['Application', 'Egress'],
      );
      return;
    }
    state = state.copyWith(
      activeChainName: bundle.activeChainLabel(activeProfileName: profile?.name),
      layerLabels: bundle.layerLabelsForPlan(plan),
    );
  }

  Future<void> _refreshHelperStatus() async {
    final info = await _controller.helperInfo();
    state = state.copyWith(
      helperStatus: info.status,
      helperAvailable: info.isReady,
      helperStatusLabel: info.statusLabel,
    );
  }

  Future<void> refreshHelperStatus() => _refreshHelperStatus();

  Future<void> registerHelper() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final status = await _controller.registerHelper();
      await _refreshHelperStatus();

      if (state.helperStatus == 'requiresApproval') {
        await _controller.openHelperSettings();
        state = state.copyWith(
          errorMessage:
              'TunnelChain registered. In System Settings → General → '
              'Login Items → Allow in Background — enable TunnelChain, then Refresh.',
        );
        return;
      }

      if (state.helperStatus == 'enabled' && state.helperAvailable) {
        state = state.copyWith(clearError: true);
        return;
      }

      if (state.helperStatus == 'notFound') {
        state = state.copyWith(
          errorMessage:
              'SMAppService does not recognize this build (adhoc signing). '
              'Login Items will stay empty. Use Connect — macOS will ask for '
              'your administrator password. For password-free connect, sign the '
              'app with an Apple Development or Developer ID certificate.',
        );
        return;
      }

      if (!state.helperAvailable) {
        state = state.copyWith(
          errorMessage: switch (status) {
            'bundleMissing' =>
              'Helper files are missing from this .app. Rebuild: '
              'flutter build macos --release',
            'requiresApproval' =>
              'Approve TunnelChain in Login Items (Allow in Background), then Refresh.',
            _ =>
              'Helper is not ready (${state.helperStatusLabel}).',
          },
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> openHelperSettings() async {
    await _controller.openHelperSettings();
  }

  Future<void> connect() async {
    state = state.copyWith(busy: true, clearAwaiting: true, clearError: true);
    try {
      await _refreshHelperStatus();

      if (state.helperStatus == 'bundleMissing') {
        state = state.copyWith(
          errorMessage:
              'Helper is missing from this app bundle. Rebuild with '
              'flutter build macos --release and open the .app from '
              'build/macos/Build/Products/Release/.',
        );
        return;
      }

      if (!state.helperAvailable) {
        final hint = state.helperStatus == 'notFound' ||
                state.helperStatus == 'notRegistered'
            ? 'Connect will prompt for your administrator password.'
            : 'Use the Helper card above: Register → approve in Login Items → Refresh.';
        state = state.copyWith(
          errorMessage:
              'Privileged helper is not ready (${state.helperStatusLabel}). $hint',
        );
        return;
      }

      final bundle = ref.read(connectBundleProvider);
      if (bundle == null) {
        state = state.copyWith(
          errorMessage:
              'Create a chain on Chains and activate a profile first.',
        );
        return;
      }

      final secrets = await loadConnectSecrets(ref);
      late final String configJson;
      try {
        configJson = generateConnectConfigJson(ref, secrets);
      } catch (e) {
        state = state.copyWith(
          errorMessage: 'Failed to build tunnel config: ${_friendlyError(e)}',
        );
        return;
      }

      final tunnel = bundle.tunnel;
      final safetyTimeoutSec = effectiveSafetyTimeoutSec(tunnel.safetyTimeoutSec);
      await _controller.connect(
        configJson: configJson,
        safetyTimeoutSec: safetyTimeoutSec,
        killSwitch: tunnel.killSwitch,
        dnsServers: SystemDnsPolicy.serversForConnect(bundle),
        searchDomains: SystemDnsPolicy.searchDomainsForConnect(bundle),
        clashApiSecret: tunnel.clashApiSecret,
      );

      state = state.copyWith(
        safetyTimeoutSec: safetyTimeoutSec,
        activeChainName: bundle.activeChainLabel(
          activeProfileName: ref.read(tunnelCatalogProvider).plan.activeProfile?.name,
        ),
        layerLabels: bundle.layerLabelsForPlan(
          ref.read(tunnelCatalogProvider).plan,
        ),
      );

      if (_controller.state == TunnelState.awaitingConfirm) {
        state = state.copyWith(
          clearError: true,
          awaitingConfirmSince: DateTime.now(),
        );
      } else if (_controller.state.isConnected) {
        state = state.copyWith(
          clearError: true,
          connectedSince: DateTime.now(),
        );
      }

      _startTrafficPolling();
      _startLiveTicker();
      await _refreshExternalIp();

      if (_controller.state == TunnelState.degraded) {
        state = state.copyWith(
          errorMessage:
              'sing-box started but Clash API is unreachable. '
              'Check ~/Library/Application Support/TunnelChain/dev.log and sing-box logs.',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> confirm() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _controller.confirm();
      state = state.copyWith(clearAwaiting: true);
      _startLiveTicker();
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  bool get _isLive => state.tunnelState.isLive;

  Future<void> reconnectIfConnected() async {
    if (!_isLive) return;
    await disconnect();
    await connect();
  }

  Future<void> disconnect() async {
    state = state.copyWith(busy: true, clearError: true);
    _stopTrafficPolling();
    _liveTicker?.cancel();
    try {
      final result = await _controller.disconnect();
      state = state.copyWith(
        resetSteps: result.steps,
        clearAwaiting: true,
        clearExternalIp: true,
        clearConnectedSince: true,
        clearTraffic: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyError(e));
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  void _onTunnelState(TunnelState next) {
    final wasConnected =
        state.tunnelState.isLive ||
        state.tunnelState == TunnelState.awaitingConfirm;
    final isLive = next.isLive || next == TunnelState.awaitingConfirm;

    state = state.copyWith(
      tunnelState: next,
      connectedSince: isLive && !wasConnected && state.connectedSince == null
          ? DateTime.now()
          : null,
      clearConnectedSince: !isLive && wasConnected,
      clearAwaiting: next != TunnelState.awaitingConfirm,
      awaitingConfirmSince: next == TunnelState.awaitingConfirm &&
              state.awaitingConfirmSince == null
          ? DateTime.now()
          : state.awaitingConfirmSince,
    );

    if (next == TunnelState.stopped || next == TunnelState.killSwitchEngaged) {
      if (next == TunnelState.stopped) {
        _stopTrafficPolling();
        _liveTicker?.cancel();
      }
    }
    if (isLive) {
      _startLiveTicker();
    }
    if (next.isConnected && _trafficSub == null) {
      _startTrafficPolling();
    }
  }

  void _startLiveTicker() {
    _liveTicker?.cancel();
    _liveTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.tunnelState.isConnected &&
          state.tunnelState != TunnelState.awaitingConfirm) {
        _liveTicker?.cancel();
        return;
      }
      state = state.copyWith();
    });
  }

  void _startTrafficPolling() {
    _trafficSub?.cancel();
    _trafficSub = null;
    _trafficSub = _controller.clashApi.trafficStream().listen(
      _onTrafficSample,
      onError: (_) => _scheduleTrafficReconnect(),
      onDone: _scheduleTrafficReconnect,
      cancelOnError: false,
    );
    state = state.copyWith(trafficLive: true);
  }

  void _onTrafficSample(TrafficSample sample) {
    if (!state.tunnelState.isConnected &&
        state.tunnelState != TunnelState.awaitingConfirm) {
      return;
    }
    final prior = state.trafficHistory;
    final history = <TrafficSample>[...prior, sample];
    if (history.length > 60) {
      history.removeRange(0, history.length - 60);
    }
    state = state.copyWith(
      uploadBps: sample.uploadBps,
      downloadBps: sample.downloadBps,
      totalUploadBytes: state.totalUploadBytes + sample.uploadBps,
      totalDownloadBytes: state.totalDownloadBytes + sample.downloadBps,
      trafficHistory: history,
      trafficLive: true,
    );
  }

  void _scheduleTrafficReconnect() {
    if (!state.tunnelState.isConnected &&
        state.tunnelState != TunnelState.awaitingConfirm) {
      return;
    }
    _trafficSub?.cancel();
    _trafficSub = null;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!state.tunnelState.isConnected &&
          state.tunnelState != TunnelState.awaitingConfirm) {
        return;
      }
      if (_trafficSub == null) {
        _startTrafficPolling();
      }
    });
  }

  void _stopTrafficPolling() {
    _trafficSub?.cancel();
    _trafficSub = null;
    state = state.copyWith(trafficLive: false);
  }

  Future<void> _refreshExternalIp() async {
    try {
      final result = await Process.run('curl', [
        '-4',
        '-s',
        '--max-time',
        '8',
        'https://api.ipify.org',
      ]);
      if (result.exitCode == 0) {
        final ip = (result.stdout as String).trim();
        if (ip.isNotEmpty) {
          state = state.copyWith(externalIp: ip);
        }
      }
    } catch (_) {}
  }

  void _dispose() {
    _stateSub?.cancel();
    _trafficSub?.cancel();
    _liveTicker?.cancel();
  }

  String _friendlyError(Object e) {
    final text = e.toString().trim();
    const prefix = 'Bad state: ';
    var message = text.startsWith(prefix) ? text.substring(prefix.length).trim() : text;
    if (message.isEmpty) {
      message = 'Unknown error — see ~/Library/Application Support/TunnelChain/dev.log';
    }
    return message;
  }
}

final coreControllerProvider = Provider<CoreController>((ref) {
  final controller = CoreController();
  ref.onDispose(controller.dispose);
  return controller;
});

final tunnelSessionProvider =
    NotifierProvider<TunnelSessionNotifier, TunnelUiState>(
      TunnelSessionNotifier.new,
    );
