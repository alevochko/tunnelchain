import 'dart:async';

import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';
import 'package:tunnel_chain/services/config_store.dart';
import 'package:tunnel_chain/services/mac_privileged_client.dart';
import 'package:tunnel_chain/services/privileged_client.dart';
import 'package:tunnel_chain/services/sing_box_path.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';

/// sing-box lifecycle + helper coordination (AR §8).
class CoreController {
  CoreController({
    PrivilegedClient? privileged,
    ClashApiClient? clashApi,
    ConfigStore? configStore,
  }) : _privileged = privileged ?? MacPrivilegedClient(),
       _clashApi = clashApi ?? ClashApiClient(),
       _configStore = configStore ?? MacConfigStore();

  final PrivilegedClient _privileged;
  final ClashApiClient _clashApi;
  final ConfigStore _configStore;

  final _stateController = StreamController<TunnelState>.broadcast();
  Stream<TunnelState> get states => _stateController.stream;

  TunnelState _state = TunnelState.stopped;
  TunnelState get state => _state;

  String? _sessionToken;
  String? _clashSecret;
  Timer? _sessionPoller;

  Future<String> configDirectory() => _configStore.configDirectory();

  void _setState(TunnelState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  Future<bool> ensureHelperRegistered() async {
    final info = await _privileged.getHelperInfo();
    if (info.isReady) return true;
    await _privileged.registerHelper();
    final after = await _privileged.getHelperInfo();
    return after.isReady;
  }

  Future<HelperInfo> helperInfo() => _privileged.getHelperInfo();

  Future<String> registerHelper() => _privileged.registerHelper();

  Future<void> openHelperSettings() => _privileged.openHelperSettings();

  Future<HelperSessionStatus> sessionStatus() => _privileged.getSessionStatus();

  Future<void> connect({
    required String configJson,
    int safetyTimeoutSec = 300,
    bool killSwitch = true,
    List<String> dnsServers = const [ConfigConstants.dnsPinIp],
    List<String> searchDomains = const [],
    String? clashApiSecret,
  }) async {
    if (_state.isLive || _state == TunnelState.starting) return;

    _setState(TunnelState.validating);
    _clashSecret = clashApiSecret;

    final configPath = await _configStore.writeConfig(configJson);

    _setState(TunnelState.starting);

    final result = await _privileged.applyConfig(
      configPath: configPath,
      safetyTimeoutSec: safetyTimeoutSec,
      killSwitch: killSwitch,
      singBoxPath: resolveBundledSingBoxPath(),
      dnsServers: dnsServers,
      searchDomains: searchDomains,
    );

    if (!result.success) {
      _setState(TunnelState.failed);
      final msg = (result.error?.trim().isNotEmpty ?? false)
          ? result.error!.trim()
          : 'applyConfig failed — see /tmp/tunnelchain-dev.log';
      throw StateError(msg);
    }

    _sessionToken = result.sessionToken;

    final api = _clashApiWithSecret();
    for (var i = 0; i < 40; i++) {
      if (await api.isReachable()) {
        _setState(
          safetyTimeoutSec > 0
              ? TunnelState.awaitingConfirm
              : TunnelState.running,
        );
        _startSessionPoller();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _setState(TunnelState.degraded);
    _startSessionPoller();
  }

  void _startSessionPoller() {
    _sessionPoller?.cancel();
    _sessionPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_state.isLive && _state != TunnelState.awaitingConfirm) {
        return;
      }
      try {
        final status = await _privileged.getSessionStatus();
        if (status.killSwitchEngaged) {
          _setState(TunnelState.killSwitchEngaged);
          return;
        }
        if (!status.sessionActive &&
            (_state.isLive || _state == TunnelState.awaitingConfirm)) {
          _sessionToken = null;
          _setState(TunnelState.stopped);
          _sessionPoller?.cancel();
        }
      } catch (_) {}
    });
  }

  Future<void> confirm() async {
    final token = _sessionToken;
    if (token == null) return;
    await _privileged.confirm(token);
    _setState(TunnelState.confirmed);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _setState(TunnelState.running);
  }

  Future<PrivilegedResult> disconnect() async {
    _sessionPoller?.cancel();
    _setState(TunnelState.resetting);
    final result = await _privileged.resetAll();
    _sessionToken = null;
    _setState(TunnelState.stopped);
    return result;
  }

  Future<PrivilegedResult> resetNetwork() async {
    _sessionPoller?.cancel();
    _setState(TunnelState.resetting);
    try {
      final result = await _privileged.resetAll();
      return result;
    } finally {
      _sessionToken = null;
      _setState(TunnelState.stopped);
    }
  }

  ClashApiClient get clashApi => _clashApiWithSecret();

  ClashApiClient _clashApiWithSecret() {
    if (_clashSecret == null) return _clashApi;
    return ClashApiClient(secret: _clashSecret!);
  }

  Future<void> dispose() async {
    _sessionPoller?.cancel();
    await _stateController.close();
    _clashApi.close();
  }
}
