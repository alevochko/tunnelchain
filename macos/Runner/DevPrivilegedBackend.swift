import Foundation

/// Development fallback when SMAppService/XPC is unavailable (unsigned / adhoc builds).
/// Temp files live under Application Support.
enum DevPrivilegedBackend {
  private static var logPath: String {
    (writableDirectory() as NSString).appendingPathComponent("dev.log")
  }

  private static func writableDirectory() -> String {
    let dir = AppPaths.configDirectory()
    try? FileManager.default.createDirectory(
      atPath: dir,
      withIntermediateDirectories: true
    )
    return dir
  }

  static func runBashScript(_ script: String, completion: @escaping (Bool, String) -> Void) {
    let name = "tunnelchain-\(UUID().uuidString).sh"
    let scriptURL = URL(fileURLWithPath: (writableDirectory() as NSString).appendingPathComponent(name))
    let logFile = shellQuote(logPath)
    let wrapped = """
    #!/bin/bash
    {
      echo "===== \(ISO8601DateFormatter().string(from: Date())) ====="
      exec >\(logFile) 2>&1
      set -x
    \(script.replacingOccurrences(of: "#!/bin/bash", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
    """

    do {
      try wrapped.write(to: scriptURL, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    } catch {
      completion(false, error.localizedDescription)
      return
    }

    let path = scriptURL.path.replacingOccurrences(of: "'", with: "'\\''")
    let source = "do shell script \"/bin/bash '\(path)'\" with administrator privileges"

    let process = Process()
    let out = Pipe()
    let err = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", source]
    process.standardOutput = out
    process.standardError = err

    DispatchQueue.global(qos: .userInitiated).async {
      defer { try? FileManager.default.removeItem(at: scriptURL) }
      do {
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let log = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
        let runLog = currentRunLog(log)
        let combined = (stderr.isEmpty ? stdout : stderr).trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 && scriptSucceeded(log: runLog) {
          completion(true, combined)
        } else {
          completion(false, formatFailure(osascript: combined, log: runLog))
        }
      } catch {
        completion(false, error.localizedDescription)
      }
    }
  }

  private static func currentRunLog(_ log: String) -> String {
    guard let range = log.range(of: "===== ", options: .backwards) else {
      return log
    }
    return String(log[range.lowerBound...])
  }

  private static func scriptSucceeded(log: String) -> Bool {
    let lines = log
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && !$0.hasPrefix("+") }
    return lines.last == "ok"
  }

  private static func formatFailure(osascript: String, log: String) -> String {
    if log.contains("unknown field \"type\"") {
      return "sing-box rejected the config DNS format. If `sing-box version` in Terminal "
        + "shows 1.12+ but Connect still fails, the elevated script may be using a wrong "
        + "binary path (non-ASCII app path). Rebuild after this update and retry.\n\n"
        + "--- script log ---\n\(String(log.suffix(3000)))\n\nFull log: \(logPath)"
    }
    if osascript.contains("User canceled") || osascript.contains("-128") {
      return "Administrator password dialog was cancelled."
    }
    if osascript.contains("ошибка типа 1")
      || osascript.contains("error type 1")
      || osascript.contains("execution error")
    {
      if !log.isEmpty {
        let tail = String(log.suffix(4000))
        return "Privileged script failed:\n\(tail)\n\nFull log: \(logPath)"
      }
      return "Privileged script failed (exit 1). See \(logPath) for details."
    }
    if osascript.contains("-60005") {
      return "Administrator authorization failed. If the password was correct, "
        + "the elevated script could not run — see \(logPath)"
    }
    if !log.isEmpty {
      let tail = String(log.suffix(4000))
      let prefix = osascript.isEmpty ? "" : "\(osascript)\n\n"
      return "\(prefix)--- script log ---\n\(tail)\n\nFull log: \(logPath)"
    }
    if osascript.isEmpty {
      return "Privileged script failed before logging. See \(logPath)"
    }
    return osascript
  }

  private static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  private static func writeWorldReadableTemp(name: String, content: String) throws -> URL {
    let url = URL(
      fileURLWithPath: (writableDirectory() as NSString).appendingPathComponent(
        "\(name)-\(UUID().uuidString)"
      )
    )
    try content.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    return url
  }

  private static func singBoxPlist(
    label: String,
    configPath: String,
    configDir: String,
    singbox: String
  ) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key><string>\(label)</string>
      <key>ProgramArguments</key>
      <array>
        <string>\(singbox)</string>
        <string>run</string>
        <string>-c</string>
        <string>\(configPath)</string>
        <string>-D</string>
        <string>\(configDir)</string>
      </array>
      <key>RunAtLoad</key><true/>
      <key>KeepAlive</key><true/>
      <key>StandardOutPath</key><string>/var/log/tunnelchain-singbox.log</string>
      <key>StandardErrorPath</key><string>/var/log/tunnelchain-singbox.err.log</string>
    </dict>
    </plist>
    """
  }

  private static func resolveSingBoxPath(explicit: String) -> String {
    if let installed = try? AppPaths.installedSingBoxPath(),
       FileManager.default.isExecutableFile(atPath: installed) {
      return installed
    }
    if let bundled = AppPaths.bundledSingBoxPath() {
      return bundled
    }
    if !explicit.isEmpty,
       FileManager.default.isExecutableFile(atPath: explicit) {
      return explicit
    }
    for fallback in ["/opt/homebrew/bin/sing-box", "/usr/local/bin/sing-box"] {
      if FileManager.default.isExecutableFile(atPath: fallback) {
        return fallback
      }
    }
    return explicit.isEmpty ? (AppPaths.bundledSingBoxPath() ?? "/usr/local/bin/sing-box") : explicit
  }

  private static func singBoxPathFileQuoted() throws -> String {
    let file = try AppPaths.writeSingBoxPathFile()
    return shellQuote(file)
  }

  static func applyConfig(
    path: String,
    safetyTimeout: Int,
    dnsServers: [String],
    searchDomains: [String],
    killSwitch: Bool,
    singBoxPath: String,
    completion: @escaping ([String: Any]) -> Void
  ) {
    let configDir = (path as NSString).deletingLastPathComponent
    let label = "com.tunnelchain.app.singbox"
    let plistPath = "/Library/LaunchDaemons/\(label).plist"
    let dns = dnsServers.isEmpty ? ["172.19.0.2"] : dnsServers
    let dnsArgs = dns.map(shellQuote).joined(separator: " ")
    let searchArgs = searchDomains.map(shellQuote).joined(separator: " ")

    let singbox = resolveSingBoxPath(explicit: singBoxPath)
    let keepAlive = killSwitch ? "false" : "true"
    do {
      _ = try AppPaths.installedSingBoxPath()
    } catch {
      completion(["success": false, "error": error.localizedDescription, "devMode": true])
      return
    }
    let plist = singBoxPlist(
      label: label,
      configPath: path,
      configDir: configDir,
      singbox: singbox
    ).replacingOccurrences(of: "<key>KeepAlive</key><true/>", with: "<key>KeepAlive</key><\(keepAlive)/>")

    let tempPlist: URL
    let singboxPathFileQuoted: String
    do {
      tempPlist = try writeWorldReadableTemp(name: "tunnelchain-singbox", content: plist)
      singboxPathFileQuoted = try singBoxPathFileQuoted()
    } catch {
      completion(["success": false, "error": error.localizedDescription, "devMode": true])
      return
    }

    let script = """
    set -euo pipefail
    SB="$(tr -d '\\r' < \(singboxPathFileQuoted))"
    [ -n "$SB" ] && [ -x "$SB" ] || { echo 'sing-box path missing:' "$SB"; exit 1; }
    xattr -dr com.apple.quarantine "$SB" 2>/dev/null || true
    chmod +x "$SB" 2>/dev/null || true
    "$SB" check -c \(shellQuote(path))
    cp \(shellQuote(tempPlist.path)) \(shellQuote(plistPath))
    chmod 644 \(shellQuote(plistPath))
    launchctl bootout "system/\(label)" >/dev/null 2>&1 || true
    launchctl bootstrap system \(shellQuote(plistPath))
    networksetup -listallnetworkservices | tail -n +2 | while IFS= read -r svc; do
      case "$svc" in \\**|"") continue ;; esac
      networksetup -setdnsservers "$svc" \(dnsArgs) >/dev/null 2>&1 || true
    \(searchDomains.isEmpty ? "" : "  networksetup -setsearchdomains \"$svc\" \(searchArgs) >/dev/null 2>&1 || true")
    done
    dscacheutil -flushcache >/dev/null 2>&1 || true
    killall -HUP mDNSResponder >/dev/null 2>&1 || true
    echo ok
    """

    runBashScript(script) { ok, message in
      try? FileManager.default.removeItem(at: tempPlist)
      if ok {
        completion([
          "success": true,
          "sessionToken": UUID().uuidString,
          "devMode": true,
          "steps": ["startSingBox": true, "setDns": true],
        ])
      } else {
        completion(["success": false, "error": message, "devMode": true])
      }
    }
  }

  static func resetAll(completion: @escaping ([String: Any]) -> Void) {
    let label = "com.tunnelchain.app.singbox"
    let script = """
    set +e
    launchctl bootout "system/\(label)" >/dev/null 2>&1
    rm -f "/Library/LaunchDaemons/\(label).plist"
    networksetup -listallnetworkservices | tail -n +2 | while IFS= read -r svc; do
      case "$svc" in \\**|"") continue ;; esac
      networksetup -setdnsservers "$svc" Empty >/dev/null 2>&1
      networksetup -setsearchdomains "$svc" Empty >/dev/null 2>&1
      networksetup -setwebproxystate "$svc" off >/dev/null 2>&1
      networksetup -setsecurewebproxystate "$svc" off >/dev/null 2>&1
      networksetup -setsocksfirewallproxystate "$svc" off >/dev/null 2>&1
    done
    pfctl -F all >/dev/null 2>&1
    pfctl -f /etc/pf.conf >/dev/null 2>&1
    dscacheutil -flushcache >/dev/null 2>&1
    killall -HUP mDNSResponder >/dev/null 2>&1
    echo ok
    """
    runBashScript(script) { ok, message in
      var payload: [String: Any] = [
        "success": ok,
        "devMode": true,
        "steps": [
          "stopSingBox": ok,
          "clearDns": ok,
          "clearProxy": ok,
          "resetPf": ok,
        ],
      ]
      if !ok { payload["error"] = message }
      completion(payload)
    }
  }

  static func stop(completion: @escaping (Bool) -> Void) {
    let label = "com.tunnelchain.app.singbox"
    runBashScript("""
    launchctl bootout "system/\(label)" >/dev/null 2>&1 || true
    echo ok
    """) { ok, _ in
      completion(ok)
    }
  }

  static func confirm(completion: @escaping (Bool) -> Void) {
    completion(true)
  }

  static func getSessionStatus(completion: @escaping ([String: Any]) -> Void) {
    DispatchQueue.global(qos: .utility).async {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
      process.arguments = ["-x", "sing-box"]
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      let running: Bool
      do {
        try process.run()
        process.waitUntilExit()
        running = process.terminationStatus == 0
      } catch {
        running = false
      }
      DispatchQueue.main.async {
        completion([
          "sessionActive": running,
          "singboxRunning": running,
          "killSwitchEngaged": false,
          "killSwitchEnabled": false,
        ])
      }
    }
  }
}
