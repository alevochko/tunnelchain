import Foundation

@objc protocol HelperProtocol {
  func resetAll(withReply reply: @escaping ([String: Any]) -> Void)
  func applyConfig(
    _ path: String,
    safetyTimeout: Int,
    dnsServers: [String],
    searchDomains: [String],
    killSwitch: Bool,
    singBoxPath: String,
    withReply reply: @escaping ([String: Any]) -> Void
  )
  func confirm(_ sessionToken: String, withReply reply: @escaping (Bool) -> Void)
  func stop(withReply reply: @escaping (Bool) -> Void)
  func ping(withReply reply: @escaping (Bool) -> Void)
  func getSessionStatus(withReply reply: @escaping ([String: Any]) -> Void)
}

@objc protocol HelperProtocolClient {
  func helperDidUpdateStatus(_ status: [String: Any])
}
