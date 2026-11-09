import AppKit

@MainActor
final class SpotifySpatialAudioAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    revealMainWindow()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    revealMainWindow()
    return true
  }

  func revealMainWindow(attemptsRemaining: Int = 8) {
    NSApplication.shared.activate(ignoringOtherApps: true)

    if let window = targetWindow {
      window.makeKeyAndOrderFront(nil)
      return
    }

    guard attemptsRemaining > 0 else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
      self?.revealMainWindow(attemptsRemaining: attemptsRemaining - 1)
    }
  }

  private var targetWindow: NSWindow? {
    NSApplication.shared.keyWindow
      ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
      ?? NSApplication.shared.windows.first(where: \.canBecomeKey)
  }
}
