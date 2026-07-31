import Foundation

/// Polls sing-box process while a tunnel session is active.
final class ProcessMonitor {
  private var timer: DispatchSourceTimer?
  private let queue = DispatchQueue(label: "com.tunnelchain.process-monitor")
  private let onSingBoxDied: () -> Void

  init(onSingBoxDied: @escaping () -> Void) {
    self.onSingBoxDied = onSingBoxDied
  }

  func start(intervalSec: Int = 2) {
    stop()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(
      deadline: .now() + .seconds(intervalSec),
      repeating: .seconds(intervalSec)
    )
    timer.setEventHandler { [weak self] in
      guard let self else { return }
      if !Self.singBoxRunning() {
        self.onSingBoxDied()
      }
    }
    timer.resume()
    self.timer = timer
  }

  func stop() {
    timer?.cancel()
    timer = nil
  }

  static func singBoxRunning() -> Bool {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-x", "sing-box"]
    process.standardOutput = pipe
    process.standardError = Pipe()
    guard (try? process.run()) != nil else { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
  }
}
