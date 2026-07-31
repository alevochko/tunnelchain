import Foundation

/// DNS, proxy, pf — privileged network mutations (FR-25).
enum NetworkOps {
  static func listNetworkServices() -> [String] {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    process.arguments = ["-listallnetworkservices"]
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return []
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let text = String(data: data, encoding: .utf8) else { return [] }
    return text
      .split(separator: "\n")
      .dropFirst()
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && !$0.hasPrefix("*") }
  }

  static func setDns(servers: [String], searchDomains: [String]) -> Bool {
    var ok = true
    for service in listNetworkServices() {
      if !runNetworkSetup(["-setdnsservers", service] + servers) {
        ok = false
      }
      if !searchDomains.isEmpty {
        if !runNetworkSetup(["-setsearchdomains", service] + searchDomains) {
          ok = false
        }
      }
    }
    flushDnsCache()
    return ok
  }

  static func clearDns() -> Bool {
    var ok = true
    for service in listNetworkServices() {
      if !runNetworkSetup(["-setdnsservers", service, "Empty"]) { ok = false }
      if !runNetworkSetup(["-setsearchdomains", service, "Empty"]) { ok = false }
    }
    flushDnsCache()
    return ok
  }

  static func clearProxy() -> Bool {
    var ok = true
    for service in listNetworkServices() {
      for flag in [
        "-setwebproxystate", "-setsecurewebproxystate",
        "-setsocksfirewallproxystate", "-setproxyautodiscovery",
      ] {
        if !runNetworkSetup([flag, service, "off"]) { ok = false }
      }
    }
    return ok
  }

  static func resetPf() -> Bool {
    let anchors = shellOutput("/sbin/pfctl", ["-s", "Anchors"]) ?? ""
    guard anchors.lowercased().contains("tunnelchain")
      || anchors.lowercased().contains("sing-box")
    else { return true }
    _ = shellOutput("/sbin/pfctl", ["-a", HelperConstants.pfAnchor, "-F", "all"])
    _ = shellOutput("/sbin/pfctl", ["-F", "all"])
    _ = shellOutput("/sbin/pfctl", ["-f", "/etc/pf.conf"])
    return true
  }

  static func removeStaleRoutes() -> Bool {
    let output = shellOutput("/usr/sbin/netstat", ["-rn", "-f", "inet"]) ?? ""
    var ok = true
    for line in output.split(separator: "\n") {
      let trimmed = String(line).trimmingCharacters(in: .whitespaces)
      guard trimmed.contains("172.19.0") else { continue }
      let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
      guard let dest = parts.first else { continue }
      let destStr = String(dest)
      if !runRoute(["delete", "-inet", destStr]) { ok = false }
    }
    return ok
  }

  @discardableResult
  private static func runRoute(_ args: [String]) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/sbin/route")
    process.arguments = args
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  private static func flushDnsCache() {
    _ = shellOutput("/usr/bin/dscacheutil", ["-flushcache"])
    _ = shellOutput("/usr/bin/killall", ["-HUP", "mDNSResponder"])
  }

  @discardableResult
  private static func runNetworkSetup(_ args: [String]) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    process.arguments = args
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  @discardableResult
  private static func shellOutput(_ path: String, _ args: [String]) -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return nil }
      return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    } catch {
      return nil
    }
  }
}
