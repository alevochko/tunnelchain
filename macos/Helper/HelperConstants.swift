import Foundation

enum HelperConstants {
  static let machServiceName = "com.tunnelchain.app.helper"
  static let helperLabel = "com.tunnelchain.app.helper"
  static let singBoxLabel = "com.tunnelchain.app.singbox"
  static let dnsPinIp = "172.19.0.2"
  static let pfAnchor = "com.tunnelchain.app"
  static let configSubpath = "Library/Application Support/TunnelChain"
  static let singBoxPaths = [
    "/Applications/TunnelChain.app/Contents/Resources/sing-box",
    "/usr/local/bin/sing-box",
    "/opt/homebrew/bin/sing-box",
  ]
  static let logOut = "/var/log/tunnelchain-singbox.log"
  static let logErr = "/var/log/tunnelchain-singbox.err.log"
}
