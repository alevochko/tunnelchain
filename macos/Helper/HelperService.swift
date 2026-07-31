import Foundation

final class HelperService: NSObject, HelperProtocol, NSXPCListenerDelegate {
  private var sessionToken: String?
  private let watchdog = Watchdog {
    _ = ResetService.resetAll()
  }

  func listener(
    _ listener: NSXPCListener,
    shouldAcceptNewConnection connection: NSXPCConnection
  ) -> Bool {
    connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
    connection.exportedObject = self
    connection.resume()
    return true
  }

  func resetAll(withReply reply: @escaping ([String: Any]) -> Void) {
    watchdog.disarm()
    sessionToken = nil
    reply(ResetService.resetAll())
  }

  func applyConfig(
    _ path: String,
    safetyTimeout: Int,
    dnsServers: [String],
    searchDomains: [String],
    withReply reply: @escaping ([String: Any]) -> Void
  ) {
    do {
      try validateConfigPath(path)
      try LaunchdManager.startSingBox(configPath: path)

      let servers = dnsServers.isEmpty ? [HelperConstants.dnsPinIp] : dnsServers
      _ = NetworkOps.setDns(servers: servers, searchDomains: searchDomains)

      let token = UUID().uuidString
      sessionToken = token
      watchdog.arm(seconds: safetyTimeout)

      reply([
        "success": true,
        "sessionToken": token,
        "steps": ["startSingBox": true, "setDns": true],
      ])
    } catch {
      _ = ResetService.resetAll()
      reply([
        "success": false,
        "error": error.localizedDescription,
      ])
    }
  }

  func confirm(_ sessionToken: String, withReply reply: @escaping (Bool) -> Void) {
    let ok = sessionToken == self.sessionToken
    if ok {
      watchdog.disarm()
    }
    reply(ok)
  }

  func stop(withReply reply: @escaping (Bool) -> Void) {
    watchdog.disarm()
    sessionToken = nil
    reply(LaunchdManager.stopSingBox())
  }

  func ping(withReply reply: @escaping (Bool) -> Void) {
    reply(true)
  }

  private func validateConfigPath(_ path: String) throws {
    let resolved = (path as NSString).standardizingPath
    guard resolved.contains("/Library/Application Support/TunnelChain/"),
          resolved.hasSuffix("config.json")
    else {
      throw NSError(domain: "TunnelChain", code: 10, userInfo: [
        NSLocalizedDescriptionKey: "config path not in Application Support/TunnelChain",
      ])
    }
    guard FileManager.default.fileExists(atPath: resolved) else {
      throw NSError(domain: "TunnelChain", code: 11, userInfo: [
        NSLocalizedDescriptionKey: "config file does not exist",
      ])
    }
    let attrs = try FileManager.default.attributesOfItem(atPath: resolved)
    let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
    guard size > 0, size < 5_000_000 else {
      throw NSError(domain: "TunnelChain", code: 12, userInfo: [
        NSLocalizedDescriptionKey: "config file size out of bounds",
      ])
    }
    if let binary = LaunchdManager.singBoxBinary() {
      let check = Process()
      check.executableURL = URL(fileURLWithPath: binary)
      check.arguments = ["check", "-c", resolved]
      check.standardOutput = Pipe()
      check.standardError = Pipe()
      try check.run()
      check.waitUntilExit()
      guard check.terminationStatus == 0 else {
        throw NSError(domain: "TunnelChain", code: 13, userInfo: [
          NSLocalizedDescriptionKey: "sing-box check failed",
        ])
      }
    }
  }
}
