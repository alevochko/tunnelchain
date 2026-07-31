import Foundation

/// Idempotent network restore (FR-25). Runs every step even if earlier ones fail.
enum ResetService {
  /// Fail-open: restore ordinary connectivity (quit, disconnect, watchdog, Doctor fix).
  static func resetAll() -> [String: Any] {
    var steps: [String: Bool] = [:]
    steps["stopSingBox"] = LaunchdManager.stopSingBox()
    steps["clearRoutes"] = NetworkOps.removeStaleRoutes()
    steps["clearDns"] = NetworkOps.clearDns()
    steps["clearProxy"] = NetworkOps.clearProxy()
    steps["resetPf"] = NetworkOps.resetPf()
    let success = steps.values.allSatisfy { $0 }
    return ["success": success, "steps": steps]
  }

  /// Fail-closed (FR-13): stop core but keep DNS pin and routes.
  static func engageKillSwitch() -> [String: Any] {
    var steps: [String: Bool] = [:]
    steps["stopSingBox"] = LaunchdManager.stopSingBox()
    let success = steps.values.allSatisfy { $0 }
    return ["success": success, "steps": steps, "killSwitchEngaged": true]
  }
}
