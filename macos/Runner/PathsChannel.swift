import Cocoa
import FlutterMacOS

/// Sandbox-safe access to real Application Support paths.
final class PathsChannel: NSObject {
  static let channelName = "com.tunnelchain/paths"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    let instance = PathsChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getConfigDirectory":
      result(AppPaths.configDirectory())

    case "getConfigFilePath":
      result(AppPaths.configFilePath())

    case "getBundledSingBoxPath":
      result(AppPaths.bundledSingBoxPath())

    case "writeConfig":
      guard let args = call.arguments as? [String: Any],
            let content = args["content"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "content required", details: nil))
        return
      }
      do {
        let path = try AppPaths.writeConfigFile(content: content)
        result(path)
      } catch {
        result(FlutterError(
          code: "write_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
