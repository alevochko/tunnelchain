import AppKit
import Foundation
import ServiceManagement

enum HelperRegistration {
  static let plistName = "com.tunnelchain.app.helper.plist"

  static func plistURL() -> URL {
    Bundle.main.bundleURL
      .appendingPathComponent("Contents/Library/LaunchDaemons/\(plistName)")
  }

  static func helperBinaryURL() -> URL {
    Bundle.main.bundleURL
      .appendingPathComponent("Contents/MacOS/TunnelChainHelper")
  }

  static func bundleFilesPresent() -> Bool {
    FileManager.default.fileExists(atPath: plistURL().path)
      && FileManager.default.fileExists(atPath: helperBinaryURL().path)
  }

  static func register() -> Bool {
    guard #available(macOS 13, *) else { return false }
    guard bundleFilesPresent() else {
      NSLog("Helper files missing: plist=\(plistURL().path) binary=\(helperBinaryURL().path)")
      return false
    }
    do {
      let service = SMAppService.daemon(plistName: plistName)
      try service.register()
      return true
    } catch {
      NSLog("SMAppService.register failed: \(error.localizedDescription)")
      return false
    }
  }

  static func statusDescription() -> String {
    guard bundleFilesPresent() else { return "bundleMissing" }
    guard #available(macOS 13, *) else { return "unsupported" }
    let service = SMAppService.daemon(plistName: plistName)
    switch service.status {
    case .enabled: return "enabled"
    case .requiresApproval: return "requiresApproval"
    case .notRegistered: return "notRegistered"
    case .notFound: return "notFound"
    @unknown default: return "unknown"
    }
  }

  static func openLoginItemsSettings() {
    let candidates = [
      "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
      "x-apple.systempreferences:com.apple.preference.security?Privacy_LoginItems",
    ]
    for raw in candidates {
      if let url = URL(string: raw) {
        NSWorkspace.shared.open(url)
        return
      }
    }
  }
}
