import AppKit
import Observation
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
  private let settings: Settings
  private let model: PracticeModel
  private let panel: PanelController
  private lazy var hotkey: HotkeyCenter = HotkeyCenter { [weak self] in
    guard let self else { return }
    if self.recorder.state == .recording, let shortcut = self.settings.hotkey {
      self.recorder.capture(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    } else {
      self.panel.handle(.hotkey)
    }
  }
  private lazy var recorder: HotkeyRecorder = HotkeyRecorder(
    settings: settings, canRecord: { [weak self] in self?.hotkey.canRecord($0) ?? false },
    register: { [weak self] in self?.hotkey.replace(with: $0) ?? false })
  private lazy var settingsWindow: SettingsWindow = SettingsWindow(
    settings: settings, model: model, recorder: recorder,
    hidePanel: { [weak self] in self?.panel.handle(.escape) })
  private var statusMenu: StatusMenu?

  override init() {
    settings = Settings(defaults: .standard)
    let directory = URL.applicationSupportDirectory.appendingPathComponent(
      "Twiddle", isDirectory: true)
    let store = Store(directory: directory, currentDate: { Date() })
    model = PracticeModel(store: store, random: SystemRandomNumberGenerator(), settings: settings)
    panel = PanelController(model: model)
    super.init()
    panel.openSettings = { [weak self] in self?.settingsWindow.show() }
  }

  func applicationWillTerminate(_ notification: Notification) {
    panel.quit()
    hotkey.stop()
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls { panel.open(url) }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    recorder.registerSaved()
    statusMenu = StatusMenu(
      model: model, settings: settings,
      practise: { [weak self] in self?.panel.practise() },
      progress: { [weak self] in self?.panel.openProgress() },
      openSettings: { [weak self] in self?.settingsWindow.show() })
    applyTheme()
    panel.launch()
  }

  private func applyTheme() {
    withObservationTracking {
      switch settings.theme {
      case .system: NSApp.appearance = nil
      case .light: NSApp.appearance = NSAppearance(named: .aqua)
      case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
      }
    } onChange: { [weak self] in
      Task { @MainActor in self?.applyTheme() }
    }
  }
}
