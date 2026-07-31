import Foundation

/// Idempotent network restore (FR-25). Runs every step even if earlier ones fail.
enum ResetService {
  static func resetAll() -> [String: Any] {
    var steps: [String: Bool] = [:]
    steps["stopSingBox"] = LaunchdManager.stopSingBox()
    steps["clearDns"] = NetworkOps.clearDns()
    steps["clearProxy"] = NetworkOps.clearProxy()
    steps["resetPf"] = NetworkOps.resetPf()
    let success = steps.values.allSatisfy { $0 }
    return ["success": success, "steps": steps]
  }
}
