import Foundation

/// Development fallback when SMAppService/XPC is unavailable (unsigned debug builds).
/// Uses a temp bash script in /tmp (readable by root after admin elevation).
enum DevPrivilegedBackend {
  private static let logPath = "/tmp/tunnelchain-dev.log"

  static func runBashScript(_ script: String, completion: @escaping (Bool, String) -> Void) {
    let name = "tunnelchain-\(UUID().uuidString).sh"
    let scriptURL = URL(fileURLWithPath: "/tmp/\(name)")
    let wrapped = """
    #!/bin/bash
    {
      echo "===== \(ISO8601DateFormatter().string(from: Date())) ====="
      exec >>\(logPath) 2>&1
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
        let combined = (stderr.isEmpty ? stdout : stderr).trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 {
          completion(true, combined)
        } else {
          let detail = log.isEmpty ? combined : "\(combined)\n\n--- script log ---\n\(log)"
          completion(false, humanize(detail))
        }
      } catch {
        completion(false, error.localizedDescription)
      }
    }
  }

  private static func humanize(_ raw: String) -> String {
    if raw.contains("-60005") && !raw.contains("script log") && raw.count < 120 {
      return "Wrong password or dialog cancelled. Press Connect again and enter your macOS administrator password."
    }
    if raw.isEmpty {
      return "Privileged script failed. See /tmp/tunnelchain-dev.log"
    }
    return raw
  }

  private static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  private static func writeWorldReadableTemp(name: String, content: String) throws -> URL {
    let url = URL(fileURLWithPath: "/tmp/\(name)-\(UUID().uuidString)")
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

    let singbox = singBoxPath.isEmpty ? "/usr/local/bin/sing-box" : singBoxPath
    let keepAlive = killSwitch ? "false" : "true"
    let plist = singBoxPlist(
      label: label,
      configPath: path,
      configDir: configDir,
      singbox: singbox
    ).replacingOccurrences(of: "<key>KeepAlive</key><true/>", with: "<key>KeepAlive</key><\(keepAlive)/>")

    let tempPlist: URL
    do {
      tempPlist = try writeWorldReadableTemp(name: "tunnelchain-singbox", content: plist)
    } catch {
      completion(["success": false, "error": error.localizedDescription, "devMode": true])
      return
    }

    let script = """
    set -euo pipefail
    SB='/usr/local/bin/sing-box'
    [ -x "$SB" ] || SB='/opt/homebrew/bin/sing-box'
    [ -x "\(shellQuote(singbox))" ] && SB=\(shellQuote(singbox))
    [ -x "$SB" ] || { echo 'sing-box not found'; exit 1; }
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
    let label = "com.tunnelchain.app.singbox"
    runBashScript("""
    if pgrep -x sing-box >/dev/null 2>&1; then echo running; else echo stopped; fi
  """) { ok, message in
      let running = message.contains("running")
      completion([
        "sessionActive": running,
        "singboxRunning": running,
        "killSwitchEngaged": false,
        "killSwitchEnabled": false,
      ])
    }
  }
}
