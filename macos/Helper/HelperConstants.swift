import Foundation

enum HelperConstants {
  static let machServiceName = "com.tunnelchain.app.helper"
  static let helperLabel = "com.tunnelchain.app.helper"
  static let singBoxLabel = "com.tunnelchain.app.singbox"
  static let dnsPinIp = "172.19.0.2"
  static let pfAnchor = "com.tunnelchain.app"
  static let configSubpath = "Library/Application Support/TunnelChain"
  static var singBoxPaths: [String] {
    var paths: [String] = []
    if let bundled = bundledSingBoxPath() {
      paths.append(bundled)
    }
    paths.append(contentsOf: [
      "/Applications/TunnelChain.app/Contents/Resources/sing-box",
      "/opt/homebrew/bin/sing-box",
      "/usr/local/bin/sing-box",
    ])
    return paths
  }
  static let logOut = "/var/log/tunnelchain-singbox.log"
  static let logErr = "/var/log/tunnelchain-singbox.err.log"

  /// `TunnelChainHelper` lives in `Contents/MacOS/` next to `Contents/Resources/sing-box`.
  static func bundledSingBoxPath() -> String? {
    guard let exec = Bundle.main.executableURL?.path else { return nil }
    let candidate = ((exec as NSString).deletingLastPathComponent as NSString)
      .appendingPathComponent("../Resources/sing-box")
    let resolved = (candidate as NSString).standardizingPath
    guard FileManager.default.isExecutableFile(atPath: resolved) else {
      return nil
    }
    return resolved
  }
}
