import 'package:flutter/services.dart';
import 'package:tunnel_chain/services/privileged_client.dart';

/// macOS platform channel → privileged helper (XPC).
class MacPrivilegedClient implements PrivilegedClient {
  MacPrivilegedClient({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.tunnelchain/privileged');

  final MethodChannel _channel;
  static const _xpcTimeout = Duration(seconds: 35);

  @override
  Future<HelperInfo> getHelperInfo() async {
    final status =
        await _channel.invokeMethod<String>('getHelperStatus') ?? 'unknown';
    final reachable = await _channel
        .invokeMethod<bool>('isHelperAvailable')
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
    return HelperInfo(status: status, xpcReachable: reachable ?? false);
  }

  @override
  Future<String> registerHelper() async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>('registerHelper')
        .timeout(const Duration(seconds: 10), onTimeout: () => null);
    return result?['status'] as String? ?? 'unknown';
  }

  @override
  Future<void> openHelperSettings() async {
    await _channel.invokeMethod<void>('openHelperSettings');
  }

  @override
  Future<PrivilegedResult> resetAll() async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>('resetAll')
        .timeout(_xpcTimeout, onTimeout: () => null);
    return PrivilegedResult.fromMap(
      result ?? {'success': false, 'error': 'helper timeout'},
    );
  }

  @override
  Future<PrivilegedResult> applyConfig({
    required String configPath,
    required int safetyTimeoutSec,
    required bool killSwitch,
    String? singBoxPath,
    List<String> dnsServers = const [],
    List<String> searchDomains = const [],
  }) async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>(
          'applyConfig',
          {
            'configPath': configPath,
            'safetyTimeoutSec': safetyTimeoutSec,
            'killSwitch': killSwitch,
            'singBoxPath': singBoxPath ?? '',
            'dnsServers': dnsServers,
            'searchDomains': searchDomains,
          },
        )
        .timeout(_xpcTimeout, onTimeout: () => null);
    return PrivilegedResult.fromMap(
      result ??
          {
            'success': false,
            'error':
                'Helper did not respond. Register helper first (see card above).',
          },
    );
  }

  @override
  Future<HelperSessionStatus> getSessionStatus() async {
    final result = await _channel
        .invokeMapMethod<String, dynamic>('getSessionStatus')
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    return HelperSessionStatus.fromMap(
      result ??
          {
            'sessionActive': false,
            'singboxRunning': false,
            'killSwitchEngaged': false,
            'killSwitchEnabled': false,
          },
    );
  }

  @override
  Future<void> confirm(String sessionToken) async {
    await _channel
        .invokeMethod<void>('confirm', {'sessionToken': sessionToken})
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop').timeout(
      const Duration(seconds: 15),
    );
  }
}
