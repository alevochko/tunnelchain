import 'dart:async';

import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/services/clash_api_client.dart';
import 'package:tunnel_chain/services/config_store.dart';
import 'package:tunnel_chain/services/mac_privileged_client.dart';
import 'package:tunnel_chain/services/privileged_client.dart';
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

  Future<void> connect({
    required String configJson,
    int safetyTimeoutSec = 300,
    List<String> dnsServers = const [ConfigConstants.dnsPinIp],
    List<String> searchDomains = const [],
    String? clashApiSecret,
  }) async {
    if (_state.isConnected || _state == TunnelState.starting) return;

    _setState(TunnelState.validating);
    _clashSecret = clashApiSecret;

    // sing-box check runs in the privileged helper (sandbox cannot execute it).
    final configPath = await _configStore.writeConfig(configJson);

    _setState(TunnelState.starting);

    final result = await _privileged.applyConfig(
      configPath: configPath,
      safetyTimeoutSec: safetyTimeoutSec,
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
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _setState(TunnelState.degraded);
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
    _setState(TunnelState.resetting);
    // resetAll already stops sing-box — one admin prompt in dev mode.
    final result = await _privileged.resetAll();
    _sessionToken = null;
    _setState(TunnelState.stopped);
    return result;
  }

  /// Idempotent full reset (FR-25 / Doctor fix) — safe when core is already stopped.
  Future<PrivilegedResult> resetNetwork() async {
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
    await _stateController.close();
    _clashApi.close();
  }
}
