import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var isQuitting = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    // Channels are registered from MainFlutterWindow when the controller is created.
  }

  /// FR-30: closing the window must not quit the app.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  /// FR-25: reset network state before quit.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if isQuitting {
      return .terminateNow
    }
    isQuitting = true
    let semaphore = DispatchSemaphore(value: 0)
    HelperXPCClient.shared.resetAll { _ in
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 10)
    return .terminateNow
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }
}
