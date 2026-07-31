import Cocoa
import FlutterMacOS

/// Flutter ↔ privileged helper bridge.
final class PrivilegedChannel: NSObject {
  static let channelName = "com.tunnelchain/privileged"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    let instance = PrivilegedChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  private func useDevBackend() -> Bool {
    HelperRegistration.statusDescription() != "enabled"
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getHelperStatus":
      result(HelperRegistration.statusDescription())

    case "isHelperAvailable":
      let status = HelperRegistration.statusDescription()
      if status == "enabled" {
        HelperXPCClient.shared.checkAvailable { ok in
          result(ok)
        }
        return
      }
      // Dev fallback: admin-password path when helper exists but is not approved yet.
      result(HelperRegistration.bundleFilesPresent())

    case "openHelperSettings":
      HelperRegistration.openLoginItemsSettings()
      result(true)

    case "registerHelper":
      guard HelperRegistration.bundleFilesPresent() else {
        result([
          "registered": false,
          "status": "bundleMissing",
          "error": "TunnelChainHelper missing from app bundle — rebuild the app.",
        ])
        return
      }
      let registered = HelperRegistration.register()
      let status = HelperRegistration.statusDescription()
      result([
        "registered": registered,
        "status": status,
        "error": registered ? nil : "SMAppService.register() failed — see Console.app",
      ])

    case "resetAll":
      if useDevBackend() {
        DevPrivilegedBackend.resetAll { payload in
          result(payload)
        }
        return
      }
      HelperXPCClient.shared.resetAll { payload in
        result(payload)
      }

    case "applyConfig":
      guard let args = call.arguments as? [String: Any],
            let configPath = args["configPath"] as? String else {
        result(FlutterError(code: "bad_args", message: "configPath required", details: nil))
        return
      }
      let timeout = args["safetyTimeoutSec"] as? Int ?? 300
      let dns = args["dnsServers"] as? [String] ?? []
      let search = args["searchDomains"] as? [String] ?? []
      let killSwitch = args["killSwitch"] as? Bool ?? true
      let singBoxPath = args["singBoxPath"] as? String ?? ""

      if useDevBackend() {
        DevPrivilegedBackend.applyConfig(
          path: configPath,
          safetyTimeout: timeout,
          dnsServers: dns,
          searchDomains: search,
          killSwitch: killSwitch,
          singBoxPath: singBoxPath
        ) { payload in
          result(payload)
        }
        return
      }

      HelperXPCClient.shared.applyConfig(
        path: configPath,
        safetyTimeout: timeout,
        dnsServers: dns,
        searchDomains: search,
        killSwitch: killSwitch,
        singBoxPath: singBoxPath
      ) { payload in
        result(payload)
      }

    case "getSessionStatus":
      if useDevBackend() {
        DevPrivilegedBackend.getSessionStatus { payload in
          result(payload)
        }
        return
      }
      HelperXPCClient.shared.getSessionStatus { payload in
        result(payload)
      }

    case "confirm":
      guard let args = call.arguments as? [String: Any],
            let token = args["sessionToken"] as? String else {
        result(FlutterError(code: "bad_args", message: "sessionToken required", details: nil))
        return
      }
      if useDevBackend() {
        DevPrivilegedBackend.confirm { ok in
          result(ok)
        }
        return
      }
      HelperXPCClient.shared.confirm(sessionToken: token) { ok in
        result(ok)
      }

    case "stop":
      if useDevBackend() {
        DevPrivilegedBackend.stop { ok in
          result(ok)
        }
        return
      }
      HelperXPCClient.shared.stop { ok in
        result(ok)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
