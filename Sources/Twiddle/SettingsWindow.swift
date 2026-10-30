import AppKit
import ServiceManagement
import SwiftUI
import TwiddleCore
import TwiddleUI

@MainActor
private final class SettingsPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
  private let window: SettingsPanel
  private let recorder: HotkeyRecorder
  private let hidePanel: () -> Void
  private var keyMonitor: Any?
  private let login = LoginSetting(
    read: { SMAppService.mainApp.status == .enabled },
    update: { enabled in
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    })

  init(
    settings: TwiddleCore.Settings, model: PracticeModel, recorder: HotkeyRecorder,
    hidePanel: @escaping () -> Void
  ) {
    self.recorder = recorder
    self.hidePanel = hidePanel
    window = SettingsPanel(
      contentRect: NSRect(origin: .zero, size: Theme.settingsSize),
      styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered, defer: false)
    super.init()
    window.title = "Twiddle Settings"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false
    window.becomesKeyOnlyIfNeeded = false
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.level = .normal
    let form = NSHostingView(
      rootView: SettingsForm(
        settings: settings, model: model, recorder: recorder, login: login))
    // The window keeps the board's size; by default the hosting view adds the title bar to it.
    form.sizingOptions = []
    window.contentView = form
    window.delegate = self
    window.setFrame(NSRect(origin: .zero, size: Theme.settingsSize), display: false)
    window.center()
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      let consumed = MainActor.assumeIsolated {
        guard let self, event.window === self.window else { return false }
        if self.recorder.state == .recording {
          if !event.isARepeat {
            self.recorder.capture(keyCode: event.keyCode, modifiers: .init(event.modifierFlags))
          }
          return true
        }
        if event.modifierFlags.contains(.command) {
          switch event.charactersIgnoringModifiers?.lowercased() {
          case "q":
            NSApp.terminate(nil)
            return true
          case "w":
            self.window.performClose(nil)
            return true
          case ",": return true
          default: break
          }
        }
        return false
      }
      return consumed ? nil : event
    }
  }

  func show() {
    hidePanel()
    login.refresh()
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    if recorder.state == .recording { recorder.cancel() }
  }

  func windowDidResignKey(_ notification: Notification) {
    if recorder.state == .recording { recorder.cancel() }
  }
}
