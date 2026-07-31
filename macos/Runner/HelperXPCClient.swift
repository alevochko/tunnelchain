import Foundation

/// XPC client for the privileged helper (AR §7.3).
final class HelperXPCClient {
  static let shared = HelperXPCClient()

  private var connection: NSXPCConnection?

  private func remote() -> HelperProtocol? {
    if connection == nil {
      let conn = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: [])
      conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
      conn.invalidationHandler = { [weak self] in self?.connection = nil }
      conn.interruptionHandler = { [weak self] in self?.connection = nil }
      conn.resume()
      connection = conn
    }
    return connection?.remoteObjectProxyWithErrorHandler { error in
      NSLog("Helper XPC error: \(error.localizedDescription)")
    } as? HelperProtocol
  }

  /// SMAppService enabled + live XPC ping.
  func checkAvailable(timeout: TimeInterval = 3, completion: @escaping (Bool) -> Void) {
    guard HelperRegistration.statusDescription() == "enabled" else {
      completion(false)
      return
    }
    guard let remote = remote() else {
      completion(false)
      return
    }
    var finished = false
    let lock = NSLock()
    func finish(_ value: Bool) {
      lock.lock()
      defer { lock.unlock() }
      guard !finished else { return }
      finished = true
      DispatchQueue.main.async {
        completion(value)
      }
    }
    remote.ping { ok in
      finish(ok)
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
      finish(false)
    }
  }

  func resetAll(completion: @escaping ([String: Any]) -> Void) {
    replyMap(timeout: 15, fallback: [
      "success": false,
      "error": "Helper timeout",
    ], completion: completion) { remote, reply in
      remote.resetAll(withReply: reply)
    }
  }

  func applyConfig(
    path: String,
    safetyTimeout: Int,
    dnsServers: [String],
    searchDomains: [String],
    completion: @escaping ([String: Any]) -> Void
  ) {
    replyMap(timeout: 30, fallback: [
      "success": false,
      "error": "Helper did not respond. Register it in System Settings → Login Items.",
    ], completion: completion) { remote, reply in
      remote.applyConfig(
        path,
        safetyTimeout: safetyTimeout,
        dnsServers: dnsServers,
        searchDomains: searchDomains,
        withReply: reply
      )
    }
  }

  func confirm(sessionToken: String, completion: @escaping (Bool) -> Void) {
    replyBool(timeout: 10, fallback: false, completion: completion) { remote, reply in
      remote.confirm(sessionToken, withReply: reply)
    }
  }

  func stop(completion: @escaping (Bool) -> Void) {
    replyBool(timeout: 10, fallback: false, completion: completion) { remote, reply in
      remote.stop(withReply: reply)
    }
  }

  private func replyMap(
    timeout: TimeInterval,
    fallback: [String: Any],
    completion: @escaping ([String: Any]) -> Void,
    call: (HelperProtocol, @escaping ([String: Any]) -> Void) -> Void
  ) {
    guard let remote = remote() else {
      completion(["success": false, "error": "helper unavailable"])
      return
    }
    var finished = false
    let lock = NSLock()
    func finish(_ value: [String: Any]) {
      lock.lock()
      defer { lock.unlock() }
      guard !finished else { return }
      finished = true
      DispatchQueue.main.async {
        completion(value)
      }
    }
    call(remote, finish)
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
      finish(fallback)
    }
  }

  private func replyBool(
    timeout: TimeInterval,
    fallback: Bool,
    completion: @escaping (Bool) -> Void,
    call: (HelperProtocol, @escaping (Bool) -> Void) -> Void
  ) {
    guard let remote = remote() else {
      completion(false)
      return
    }
    var finished = false
    let lock = NSLock()
    func finish(_ value: Bool) {
      lock.lock()
      defer { lock.unlock() }
      guard !finished else { return }
      finished = true
      DispatchQueue.main.async {
        completion(value)
      }
    }
    call(remote, finish)
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
      finish(fallback)
    }
  }
}

enum HelperConstants {
  static let machServiceName = "com.tunnelchain.app.helper"
}
