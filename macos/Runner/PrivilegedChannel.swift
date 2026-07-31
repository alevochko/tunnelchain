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
      if useDevBackend() && HelperRegistration.bundleFilesPresent() {
        result("devMode")
      } else {
        result(HelperRegistration.statusDescription())
      }

    case "isHelperAvailable":
      if useDevBackend() {
        result(HelperRegistration.bundleFilesPresent())
        return
      }
      HelperXPCClient.shared.checkAvailable { ok in
        result(ok)
      }

    case "openHelperSettings":
      HelperRegistration.openLoginItemsSettings()
      result(true)

    case "registerHelper":
      if useDevBackend() {
        result([
          "registered": HelperRegistration.bundleFilesPresent(),
          "status": "devMode",
        ])
        return
      }
      let registered = HelperRegistration.register()
      result([
        "registered": registered,
        "status": HelperRegistration.statusDescription(),
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

      if useDevBackend() {
        DevPrivilegedBackend.applyConfig(
          path: configPath,
          safetyTimeout: timeout,
          dnsServers: dns,
          searchDomains: search
        ) { payload in
          result(payload)
        }
        return
      }

      HelperXPCClient.shared.applyConfig(
        path: configPath,
        safetyTimeout: timeout,
        dnsServers: dns,
        searchDomains: search
      ) { payload in
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
