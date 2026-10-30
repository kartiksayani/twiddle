import AppKit
import TwiddleCore

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
  private let panel: PanelController
  private lazy var hotkey = HotkeyCenter { [weak self] in
    self?.panel.handle(.hotkey)
  }

  override init() {
    let directory = URL.applicationSupportDirectory.appendingPathComponent(
      "Twiddle", isDirectory: true)
    let store = Store(directory: directory, currentDate: { Date() })
    panel = PanelController(
      model: PracticeModel(store: store, random: SystemRandomNumberGenerator()))
    super.init()
  }

  func applicationWillTerminate(_ notification: Notification) {
    panel.quit()
    hotkey.stop()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      try hotkey.start()
      panel.launch()
    } catch {
      NSLog("Twiddle could not register Control-Option-Space: %@", String(describing: error))
      NSApp.terminate(nil)
    }
  }
}
