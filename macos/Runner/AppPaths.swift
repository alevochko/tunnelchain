import Foundation

/// Real user paths outside the App Sandbox container.
enum AppPaths {
  static func realUserHomeDirectory() -> String {
    if let passwd = getpwuid(getuid()) {
      return String(cString: passwd.pointee.pw_dir)
    }
    return NSHomeDirectory()
  }

  static func configDirectory() -> String {
    (realUserHomeDirectory() as NSString).appendingPathComponent(
      "Library/Application Support/TunnelChain"
    )
  }

  static func configFilePath() -> String {
    (configDirectory() as NSString).appendingPathComponent("config.json")
  }

  /// Bundled sing-box inside the .app (UTF-8 safe — resolve in Swift, not via osascript).
  static func bundledSingBoxPath() -> String? {
    let path = Bundle.main.bundleURL
      .appendingPathComponent("Contents/Resources/sing-box")
      .path
    guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
    return path
  }

  static func singBoxPathFile() -> String {
    (configDirectory() as NSString).appendingPathComponent("singbox.path")
  }

  @discardableResult
  static func writeSingBoxPathFile() throws -> String {
    let bundled = try installedSingBoxPath()
    let path = singBoxPathFile()
    try bundled.write(toFile: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o644],
      ofItemAtPath: path
    )
    return path
  }

  /// Copies bundled sing-box into Application Support (ASCII path, stable for root/launchd).
  @discardableResult
  static func installedSingBoxPath() throws -> String {
    guard let bundled = bundledSingBoxPath() else {
      throw NSError(
        domain: "AppPaths",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "sing-box not found in app bundle"]
      )
    }
    let dir = configDirectory()
    try FileManager.default.createDirectory(
      atPath: dir,
      withIntermediateDirectories: true
    )
    let dest = (dir as NSString).appendingPathComponent("sing-box")
    let fm = FileManager.default
    let bundledAttrs = try fm.attributesOfItem(atPath: bundled)
    let bundledDate = bundledAttrs[.modificationDate] as? Date ?? .distantPast
    var needsCopy = true
    if fm.fileExists(atPath: dest),
       let destAttrs = try? fm.attributesOfItem(atPath: dest),
       let destDate = destAttrs[.modificationDate] as? Date,
       destDate >= bundledDate {
      needsCopy = false
    }
    if needsCopy {
      if fm.fileExists(atPath: dest) {
        try fm.removeItem(atPath: dest)
      }
      try fm.copyItem(atPath: bundled, toPath: dest)
      try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
    }
    return dest
  }

  @discardableResult
  static func writeConfigFile(content: String) throws -> String {
    let dir = configDirectory()
    try FileManager.default.createDirectory(
      atPath: dir,
      withIntermediateDirectories: true
    )
    let path = configFilePath()
    try content.write(toFile: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o600],
      ofItemAtPath: path
    )
    return path
  }
}
