import Cocoa
import FlutterMacOS

/// Rounded window chrome — only clips the native frame; title bar layout stays system-managed.
enum WindowChrome {
  static let cornerRadius: CGFloat = 20

  static func apply(to window: NSWindow) {
    applyCornerRadius(to: window)
  }

  private static func applyCornerRadius(to window: NSWindow) {
    guard let frameView = window.contentView?.superview else { return }
    frameView.wantsLayer = true
    frameView.layer?.cornerRadius = cornerRadius
    frameView.layer?.masksToBounds = true
    frameView.layer?.cornerCurve = .continuous
  }
}

/// Flutter → native hook to re-apply chrome after window_manager changes.
enum WindowChromeChannel {
  static let name = "com.tunnelchain/window_chrome"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: name,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "apply":
        if let window = controller.view.window {
          WindowChrome.apply(to: window)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
