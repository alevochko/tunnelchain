import FlutterMacOS

/// Registers all custom Flutter method channels once the view controller exists.
enum NativeChannels {
  static func register(with controller: FlutterViewController) {
    PathsChannel.register(with: controller)
    KeychainChannel.register(with: controller)
    PrivilegedChannel.register(with: controller)
    DragDropChannel.register(with: controller)
    WindowChromeChannel.register(with: controller)
    StatusBarMenuController.shared.install(with: controller)
  }
}
