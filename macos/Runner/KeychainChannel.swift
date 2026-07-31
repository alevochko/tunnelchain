import Cocoa
import FlutterMacOS
import LocalAuthentication
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
    case "loadSecrets":
      guard let args = call.arguments as? [String: Any],
            let keys = args["keys"] as? [String]
      else {
        result(FlutterError(code: "bad_args", message: "keys required", details: nil))
        return
      }
      result(Self.loadSecrets(requestedKeys: Set(keys)))

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
    readWithContext(key: key, context: nil)
  }

  private static func readWithContext(key: String, context: LAContext?) -> String? {
    var query = baseQuery(key: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    if let context {
      query[kSecUseAuthenticationContext as String] = context
    }

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  /// Vault read + optional legacy migration in one Keychain auth session.
  private static func loadSecrets(requestedKeys: Set<String>) -> [String: Any] {
    let context = LAContext()
    context.localizedReason = "TunnelChain needs access to stored tunnel credentials."

    var vault = parseVaultJson(readWithContext(key: vaultAccount, context: context))
    var output: [String: String] = [:]

    for key in requestedKeys {
      if let value = vault[key], !value.isEmpty {
        output[key] = value
      }
    }

    let missing = requestedKeys.subtracting(output.keys)
    var migrated = false
    for key in missing.sorted() {
      if let value = readWithContext(key: key, context: context), !value.isEmpty {
        vault[key] = value
        output[key] = value
        migrated = true
        delete(key: key)
      }
    }

    if migrated {
      try? upsert(key: vaultAccount, value: encodeVaultJson(vault), context: context)
    }

    return [
      "secrets": output,
      "vaultJson": encodeVaultJson(vault),
    ]
  }

  private static func parseVaultJson(_ raw: String?) -> [String: String] {
    guard let raw, let data = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let map = object as? [String: Any]
    else {
      return [:]
    }
    var vault: [String: String] = [:]
    for (key, value) in map {
      let stringValue = "\(value)"
      if !stringValue.isEmpty {
        vault[key] = stringValue
      }
    }
    return vault
  }

  private static func encodeVaultJson(_ vault: [String: String]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: vault),
          let json = String(data: data, encoding: .utf8)
    else {
      return "{}"
    }
    return json
  }

  /// Reads secrets in one Dart→native call (sequential reads, shared auth context).
  private static func readAll(requestedKeys: Set<String>) -> [String: String] {
    let context = LAContext()
    var output: [String: String] = [:]
    for key in requestedKeys.sorted() {
      if let value = readWithContext(key: key, context: context), !value.isEmpty {
        output[key] = value
      }
    }
    return output
  }

  private static func write(key: String, value: String) throws {
    try upsert(key: key, value: value, context: nil)
  }

  private static func upsert(key: String, value: String, context: LAContext?) throws {
    guard let data = value.data(using: .utf8) else {
      throw NSError(
        domain: "KeychainChannel",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 secret value"]
      )
    }

    var attributes: [String: Any] = [kSecValueData as String: data]
    if context != nil {
      attributes[kSecUseAuthenticationContext as String] = context
    }

    let updateStatus = SecItemUpdate(baseQuery(key: key) as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }
    if updateStatus != errSecItemNotFound {
      throw NSError(
        domain: "KeychainChannel",
        code: Int(updateStatus),
        userInfo: [NSLocalizedDescriptionKey: "SecItemUpdate failed (\(updateStatus))"]
      )
    }

    var query = baseQuery(key: key)
    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    if let context {
      query[kSecUseAuthenticationContext as String] = context
    }

    let addStatus = SecItemAdd(query as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw NSError(
        domain: "KeychainChannel",
        code: Int(addStatus),
        userInfo: [NSLocalizedDescriptionKey: "SecItemAdd failed (\(addStatus))"]
      )
    }
  }

  @discardableResult
  private static func delete(key: String) -> OSStatus {
    SecItemDelete(baseQuery(key: key) as CFDictionary)
  }
}
