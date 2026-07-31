/// Result of a privileged helper operation (XPC → Dart).
class PrivilegedResult {
  const PrivilegedResult({
    required this.success,
    this.steps = const {},
    this.sessionToken,
    this.error,
  });

  factory PrivilegedResult.fromMap(Map<dynamic, dynamic> map) {
    final stepsRaw = map['steps'];
    final steps = <String, bool>{};
    if (stepsRaw is Map) {
      stepsRaw.forEach((key, value) {
        steps['$key'] = value == true;
      });
    }
    return PrivilegedResult(
      success: map['success'] == true,
      steps: steps,
      sessionToken: map['sessionToken'] as String?,
      error: map['error'] as String?,
    );
  }

  final bool success;
  final Map<String, bool> steps;
  final String? sessionToken;
  final String? error;
}

/// Live helper session snapshot (FR-13 / FR-24).
class HelperSessionStatus {
  const HelperSessionStatus({
    required this.sessionActive,
    required this.singboxRunning,
    required this.killSwitchEngaged,
    required this.killSwitchEnabled,
  });

  factory HelperSessionStatus.fromMap(Map<dynamic, dynamic> map) {
    return HelperSessionStatus(
      sessionActive: map['sessionActive'] == true,
      singboxRunning: map['singboxRunning'] == true,
      killSwitchEngaged: map['killSwitchEngaged'] == true,
      killSwitchEnabled: map['killSwitchEnabled'] == true,
    );
  }

  final bool sessionActive;
  final bool singboxRunning;
  final bool killSwitchEngaged;
  final bool killSwitchEnabled;
}

/// SMAppService registration state + live XPC reachability.
class HelperInfo {
  const HelperInfo({
    required this.status,
    required this.xpcReachable,
  });

  final String status;
  final bool xpcReachable;

  bool get isReady =>
      (status == 'enabled' && xpcReachable) ||
      (status == 'devMode' && xpcReachable);

  String get statusLabel => switch (status) {
    'enabled' => xpcReachable ? 'Ready' : 'Registered but not responding',
    'devMode' => 'Development mode (admin password)',
    'requiresApproval' => 'Waiting for approval',
    'notRegistered' => 'Not registered',
    'notFound' => 'Daemon plist not recognized',
    'bundleMissing' => 'Helper missing from app bundle',
    'unsupported' => 'Unsupported macOS version',
    _ => status,
  };
}

/// Fixed XPC surface (AR §7.3). No arbitrary shell commands.
abstract class PrivilegedClient {
  Future<HelperInfo> getHelperInfo();

  Future<String> registerHelper();

  Future<void> openHelperSettings();

  Future<PrivilegedResult> resetAll();

  Future<PrivilegedResult> applyConfig({
    required String configPath,
    required int safetyTimeoutSec,
    required bool killSwitch,
    String? singBoxPath,
    List<String> dnsServers,
    List<String> searchDomains,
  });

  Future<void> confirm(String sessionToken);

  Future<void> stop();

  Future<HelperSessionStatus> getSessionStatus();
}
