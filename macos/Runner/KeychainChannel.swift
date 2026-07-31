import Cocoa
import FlutterMacOS
import Security

/// macOS Keychain access for profile secrets (FR-4).
final class KeychainChannel: NSObject {
  static let channelName = "com.tunnelchain/keychain"
  private static let service = "com.tunnelchain.app.secrets"
  fileprivate static let vaultAccount = "__vault__"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    let instance = KeychainChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "read":
      guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "key required", details: nil))
        return
      }
      result(Self.read(key: key))

    case "readVault":
      result(Self.read(key: Self.vaultAccount))

    case "writeVault":
      guard let args = call.arguments as? [String: Any],
            let json = args["json"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "json required", details: nil))
        return
      }
      do {
        try Self.write(key: Self.vaultAccount, value: json)
        result(true)
      } catch {
        result(FlutterError(
          code: "write_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }

    case "readAll":
      guard let args = call.arguments as? [String: Any],
            let keys = args["keys"] as? [String]
      else {
        result(FlutterError(code: "bad_args", message: "keys required", details: nil))
        return
      }
      result(Self.readAll(requestedKeys: Set(keys)))

    case "write":
      guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            let value = args["value"] as? String
      else {
        result(
          FlutterError(code: "bad_args", message: "key and value required", details: nil)
        )
        return
      }
      do {
        try Self.write(key: key, value: value)
        result(true)
      } catch {
        result(FlutterError(
          code: "write_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }

    case "delete":
      guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "key required", details: nil))
        return
      }
      Self.delete(key: key)
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func baseQuery(key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
  }

  private static func read(key: String) -> String? {
    var query = baseQuery(key: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  /// Reads secrets in one Dart→native call (sequential reads, shared auth context).
  private static func readAll(requestedKeys: Set<String>) -> [String: String] {
    var output: [String: String] = [:]
    for key in requestedKeys.sorted() {
      if let value = read(key: key), !value.isEmpty {
        output[key] = value
      }
    }
    return output
  }

  private static func write(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw NSError(
        domain: "KeychainChannel",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 secret value"]
      )
    }

    delete(key: key)

    // macOS: plain accessibility — SecAccessControl often breaks reads in debug builds.
    var query = baseQuery(key: key)
    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw NSError(
        domain: "KeychainChannel",
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "SecItemAdd failed (\(status))"]
      )
    }
  }

  @discardableResult
  private static func delete(key: String) -> OSStatus {
    SecItemDelete(baseQuery(key: key) as CFDictionary)
  }
}
