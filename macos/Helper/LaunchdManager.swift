import Foundation

enum LaunchdManager {
  static var plistPath: String {
    "/Library/LaunchDaemons/\(HelperConstants.singBoxLabel).plist"
  }

  static func singBoxBinary(preferredPath: String? = nil) -> String? {
    if let preferred = preferredPath,
       !preferred.isEmpty,
       FileManager.default.isExecutableFile(atPath: preferred) {
      return preferred
    }
    for path in HelperConstants.singBoxPaths
      where FileManager.default.isExecutableFile(atPath: path) {
      return path
    }
    return nil
  }

  static func stopSingBox() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = ["bootout", "system/\(HelperConstants.singBoxLabel)"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
      try process.run()
      process.waitUntilExit()
      return true
    } catch {
      return false
    }
  }

  static func startSingBox(
    configPath: String,
    keepAlive: Bool = true,
    binaryPath: String? = nil
  ) throws {
    guard let binary = singBoxBinary(preferredPath: binaryPath) else {
      throw NSError(domain: "TunnelChain", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "sing-box binary not found",
      ])
    }

    let configDir = (configPath as NSString).deletingLastPathComponent
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key><string>\(HelperConstants.singBoxLabel)</string>
      <key>ProgramArguments</key>
      <array>
        <string>\(binary)</string>
        <string>run</string>
        <string>-c</string>
        <string>\(configPath)</string>
        <string>-D</string>
        <string>\(configDir)</string>
      </array>
      <key>RunAtLoad</key><true/>
      <key>KeepAlive</key><\(keepAlive ? "true" : "false")/>
      <key>ProcessType</key><string>Interactive</string>
      <key>StandardOutPath</key><string>\(HelperConstants.logOut)</string>
      <key>StandardErrorPath</key><string>\(HelperConstants.logErr)</string>
    </dict>
    </plist>
    """

    try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o644],
      ofItemAtPath: plistPath
    )

    _ = stopSingBox()

    let bootstrap = Process()
    bootstrap.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    bootstrap.arguments = ["bootstrap", "system", plistPath]
    bootstrap.standardOutput = Pipe()
    bootstrap.standardError = Pipe()
    try bootstrap.run()
    bootstrap.waitUntilExit()
    guard bootstrap.terminationStatus == 0 else {
      throw NSError(domain: "TunnelChain", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "launchctl bootstrap failed (\(bootstrap.terminationStatus))",
      ])
    }
  }
}
