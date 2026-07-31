import Cocoa
import FlutterMacOS

// MARK: - Connect row (Tailscale-style title + subtitle + switch)

private final class StatusBarConnectRowView: NSView {
  private let titleLabel = NSTextField(labelWithString: "TunnelChain")
  private let subtitleLabel = NSTextField(labelWithString: "")
  private let toggle = NSSwitch()
  private var onToggle: ((Bool) -> Void)?

  init(
    width: CGFloat,
    switchOn: Bool,
    subtitle: String,
    enabled: Bool,
    onToggle: @escaping (Bool) -> Void
  ) {
    super.init(frame: NSRect(x: 0, y: 0, width: width, height: 54))
    self.onToggle = onToggle

    titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    titleLabel.textColor = .labelColor
    styleLabel(titleLabel)

    subtitleLabel.stringValue = subtitle
    subtitleLabel.font = NSFont.systemFont(ofSize: 11)
    subtitleLabel.textColor = .secondaryLabelColor
    styleLabel(subtitleLabel)

    toggle.state = switchOn ? .on : .off
    toggle.isEnabled = enabled
    toggle.controlSize = .regular
    toggle.target = self
    toggle.action = #selector(switchChanged(_:))

    addSubview(titleLabel)
    addSubview(subtitleLabel)
    addSubview(toggle)

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    toggle.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      heightAnchor.constraint(equalToConstant: 54),
      titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),
      titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

      subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
      subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),

      toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func styleLabel(_ field: NSTextField) {
    field.isBezeled = false
    field.drawsBackground = false
    field.isEditable = false
    field.isSelectable = false
    field.lineBreakMode = .byTruncatingTail
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 280, height: 54)
  }

  @objc private func switchChanged(_ sender: NSSwitch) {
    onToggle?(sender.state == .on)
  }
}

/// Native macOS menu-bar status item (NSStatusItem + NSMenu).
final class StatusBarMenuController: NSObject, NSMenuDelegate {
  static let channelName = "com.tunnelchain/status_bar"
  static let shared = StatusBarMenuController()

  private var statusItem: NSStatusItem?
  private var dartChannel: FlutterMethodChannel?
  private var snapshot = MenuSnapshot.empty

  private struct MenuSnapshot {
    var profiles: [(id: String, name: String)]
    var activeProfileId: String?
    var connected: Bool
    var canConnect: Bool
    var canDisconnect: Bool
    var busy: Bool
    var switchOn: Bool
    var switchEnabled: Bool
    var statusLine: String
    var connectSubtitle: String

    static let empty = MenuSnapshot(
      profiles: [],
      activeProfileId: nil,
      connected: false,
      canConnect: false,
      canDisconnect: false,
      busy: false,
      switchOn: false,
      switchEnabled: false,
      statusLine: "Disconnected",
      connectSubtitle: "Not Connected"
    )
  }

  func install(with controller: FlutterViewController) {
    dartChannel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    dartChannel?.setMethodCallHandler(handleDartCall)

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem = item

    if let button = item.button {
      button.image = statusBarImage(connected: false)
      button.toolTip = "TunnelChain"
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
  }

  private func statusBarImage(connected: Bool) -> NSImage? {
    guard let base = NSImage(named: "StatusBarIcon") else {
      return NSImage(systemSymbolName: "link.circle", accessibilityDescription: "TunnelChain")
    }
    let color: NSColor = connected ? .labelColor : .secondaryLabelColor
    return tintedImage(base, color: color, size: NSSize(width: 18, height: 18))
  }

  private func tintedImage(_ image: NSImage, color: NSColor, size: NSSize) -> NSImage {
    let result = NSImage(size: size)
    result.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    image.draw(
      in: rect,
      from: NSRect(origin: .zero, size: image.size),
      operation: .sourceOver,
      fraction: 1.0
    )
    color.set()
    rect.fill(using: .sourceAtop)
    result.unlockFocus()
    result.isTemplate = false
    return result
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    guard let statusItem else { return }
    let menu = buildMenu()
    menu.delegate = self
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
  }

  func menuDidClose(_ menu: NSMenu) {
    statusItem?.menu = nil
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    menu.minimumWidth = 280

    addConnectRow(to: menu)
    menu.addItem(.separator())

    menu.addItem(sectionHeader("Profiles"))
    if snapshot.profiles.isEmpty {
      let empty = NSMenuItem(title: "No profiles yet", action: nil, keyEquivalent: "")
      empty.isEnabled = false
      menu.addItem(empty)
    } else {
      for profile in snapshot.profiles {
        let item = NSMenuItem(
          title: profile.name,
          action: #selector(profileSelected(_:)),
          keyEquivalent: ""
        )
        item.target = self
        item.representedObject = profile.id
        item.state = profile.id == snapshot.activeProfileId ? .on : .off
        if profile.id == snapshot.activeProfileId && snapshot.connected {
          item.attributedTitle = attributedProfile(
            name: profile.name,
            subtitle: "Active"
          )
        }
        item.isEnabled = !snapshot.busy
        menu.addItem(item)
      }
    }

    menu.addItem(.separator())

    let openItem = NSMenuItem(
      title: "Open TunnelChain",
      action: #selector(openApp),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)

    let hideItem = NSMenuItem(
      title: "Hide TunnelChain",
      action: #selector(hideApp),
      keyEquivalent: "h"
    )
    hideItem.target = self
    menu.addItem(hideItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit TunnelChain",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  private func addConnectRow(to menu: NSMenu) {
    let item = NSMenuItem()
    let row = StatusBarConnectRowView(
      width: 280,
      switchOn: snapshot.switchOn,
      subtitle: snapshot.connectSubtitle,
      enabled: snapshot.switchEnabled
    ) { [weak self] turnedOn in
      guard let self else { return }
      if turnedOn {
        self.invokeDart("connect")
      } else {
        self.invokeDart("disconnect")
      }
    }
    row.frame = NSRect(x: 0, y: 0, width: 280, height: 54)
    item.view = row
    item.isEnabled = true
    menu.addItem(item)
  }

  private func sectionHeader(_ title: String) -> NSMenuItem {
    let item = NSMenuItem()
    item.isEnabled = false
    item.attributedTitle = NSAttributedString(
      string: title.uppercased(),
      attributes: [
        .foregroundColor: NSColor.secondaryLabelColor,
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
      ]
    )
    return item
  }

  private func attributedProfile(name: String, subtitle: String) -> NSAttributedString {
    let result = NSMutableAttributedString(
      string: name,
      attributes: [
        .foregroundColor: NSColor.labelColor,
        .font: NSFont.systemFont(ofSize: 13),
      ]
    )
    result.append(
      NSAttributedString(
        string: "\n\(subtitle)",
        attributes: [
          .foregroundColor: NSColor.secondaryLabelColor,
          .font: NSFont.systemFont(ofSize: 11),
        ]
      )
    )
    return result
  }

  // MARK: - Menu actions

  @objc private func profileSelected(_ sender: NSMenuItem) {
    guard let profileId = sender.representedObject as? String else { return }
    invokeDart("selectProfile", arguments: profileId)
  }

  @objc private func openApp() {
    NSApp.activate(ignoringOtherApps: true)
    for window in NSApp.windows where window.canBecomeMain {
      window.makeKeyAndOrderFront(nil)
      return
    }
  }

  @objc private func hideApp() {
    for window in NSApp.windows where window.isVisible {
      window.orderOut(nil)
    }
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  private func invokeDart(_ method: String, arguments: Any? = nil) {
    dartChannel?.invokeMethod(method, arguments: arguments)
  }

  // MARK: - Dart → native

  private func handleDartCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateState":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "state map required", details: nil))
        return
      }
      snapshot = parseSnapshot(args)
      updateStatusPresentation()
      result(nil)

    case "showWindow":
      openApp()
      result(nil)

    case "hideWindow":
      hideApp()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func parseSnapshot(_ args: [String: Any]) -> MenuSnapshot {
    let profilesRaw = args["profiles"] as? [[String: Any]] ?? []
    let profiles = profilesRaw.compactMap { entry -> (id: String, name: String)? in
      guard let id = entry["id"] as? String,
            let name = entry["name"] as? String else { return nil }
      return (id, name)
    }
    return MenuSnapshot(
      profiles: profiles,
      activeProfileId: args["activeProfileId"] as? String,
      connected: args["connected"] as? Bool ?? false,
      canConnect: args["canConnect"] as? Bool ?? false,
      canDisconnect: args["canDisconnect"] as? Bool ?? false,
      busy: args["busy"] as? Bool ?? false,
      switchOn: args["switchOn"] as? Bool ?? (args["connected"] as? Bool ?? false),
      switchEnabled: args["switchEnabled"] as? Bool ?? false,
      statusLine: args["statusLine"] as? String ?? "Disconnected",
      connectSubtitle: args["connectSubtitle"] as? String ?? "Not Connected"
    )
  }

  private func updateStatusPresentation() {
    statusItem?.button?.image = statusBarImage(connected: snapshot.connected)
    statusItem?.button?.toolTip = snapshot.statusLine
  }
}
