import AppKit

@main
@MainActor
struct TwiddleApp {
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.setActivationPolicy(.accessory)
    application.delegate = delegate
    withExtendedLifetime(delegate) {
      application.run()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let panel = PanelController()
  private lazy var hotkey = HotkeyCenter { [weak self] in
    self?.panel.handle(.hotkey)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      try hotkey.start()
    } catch {
      NSLog("Twiddle could not register Control-Option-Space: %@", String(describing: error))
      NSApp.terminate(nil)
    }
  }
}
