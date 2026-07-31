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
