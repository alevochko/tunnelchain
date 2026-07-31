import Foundation

/// Safety timeout — auto-reset if user never confirms (FR-24).
final class Watchdog {
  private var timer: DispatchSourceTimer?
  private let queue = DispatchQueue(label: "com.tunnelchain.watchdog")
  private let onTimeout: () -> Void

  init(onTimeout: @escaping () -> Void) {
    self.onTimeout = onTimeout
  }

  func arm(seconds: Int) {
    disarm()
    guard seconds > 0 else { return }
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + .seconds(seconds))
    timer.setEventHandler { [weak self] in
      self?.onTimeout()
      self?.disarm()
    }
    timer.resume()
    self.timer = timer
  }

  func disarm() {
    timer?.cancel()
    timer = nil
  }
}
