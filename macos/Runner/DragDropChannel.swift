import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// File drop onto the main window — no CocoaPods plugin required.
final class DragDropChannel: NSObject {
  static let channelName = "com.tunnelchain/drag_drop"

  private var channel: FlutterMethodChannel?
  private var overlay: DropOverlayView?

  static func register(with controller: FlutterViewController) {
    let instance = DragDropChannel()
    instance.channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    instance.channel?.setMethodCallHandler(instance.handle)

    let overlay = DropOverlayView(frame: controller.view.bounds)
    overlay.autoresizingMask = [.width, .height]
    overlay.isHidden = false
    overlay.isActive = false
    overlay.onDragState = { active in
      instance.channel?.invokeMethod("onDragState", arguments: active)
    }
    overlay.onFileContent = { content in
      instance.channel?.invokeMethod("onFileDropped", arguments: content)
    }
    controller.view.addSubview(overlay)
    instance.overlay = overlay
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setListening":
      let enabled = call.arguments as? Bool ?? false
      overlay?.isActive = enabled
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

private final class DropOverlayView: NSView {
  var onFileContent: ((String) -> Void)?
  var onDragState: ((Bool) -> Void)?

  var isActive = false {
    didSet { needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("public.file-url")])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    isActive ? self : nil
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard isActive else { return [] }
    onDragState?(true)
    return .copy
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    onDragState?(false)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard isActive else { return false }
    onDragState?(false)

    let pasteboard = sender.draggingPasteboard
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
       let url = urls.first {
      return readAndDeliver(url: url)
    }

    if let paths = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String],
       let path = paths.first {
      return readAndDeliver(url: URL(fileURLWithPath: path))
    }

    return false
  }

  private func readAndDeliver(url: URL) -> Bool {
    do {
      let content = try String(contentsOf: url, encoding: .utf8)
      onFileContent?(content)
      return true
    } catch {
      return false
    }
  }
}
