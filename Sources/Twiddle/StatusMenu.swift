import AppKit
import TwiddleCore
import TwiddleUI

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let menu = NSMenu()
  private let model: PracticeModel
  private let settings: TwiddleCore.Settings
  private let practise: () -> Void
  private let progress: () -> Void
  private let openSettings: () -> Void
  private let practiseItem = NSMenuItem(
    title: "Practise", action: #selector(practiseAction), keyEquivalent: "")
  private let todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

  init(
    model: PracticeModel, settings: TwiddleCore.Settings, practise: @escaping () -> Void,
    progress: @escaping () -> Void, openSettings: @escaping () -> Void
  ) {
    self.model = model
    self.settings = settings
    self.practise = practise
    self.progress = progress
    self.openSettings = openSettings
    super.init()
    let image = NSImage(size: Theme.statusIconSize, flipped: false) { _ in
      NSColor.black.setStroke()
      let outline = NSBezierPath(
        roundedRect: Theme.statusIconRect,
        xRadius: Theme.statusIconRadius - Theme.statusIconStroke / 2,
        yRadius: Theme.statusIconRadius - Theme.statusIconStroke / 2)
      outline.lineWidth = Theme.statusIconStroke
      outline.stroke()
      NSColor.black.setFill()
      NSBezierPath(
        roundedRect: Theme.statusCaretRect,
        xRadius: Theme.statusIconStroke / 2, yRadius: Theme.statusIconStroke / 2
      ).fill()
      return true
    }
    image.isTemplate = true
    item.button?.image = image
    item.button?.toolTip = "Twiddle"
    menu.autoenablesItems = false
    menu.delegate = self
    practiseItem.target = self
    menu.addItem(practiseItem)
    todayItem.isEnabled = false
    menu.addItem(todayItem)
    menu.addItem(.separator())
    add("Progress", key: "p", action: #selector(progressAction))
    add("Settings…", key: ",", action: #selector(settingsAction))
    menu.addItem(.separator())
    add("Quit Twiddle", key: "q", action: #selector(quitAction))
    item.menu = menu
  }

  private func add(_ title: String, key: String, action: Selector) {
    let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
    entry.target = self
    menu.addItem(entry)
  }

  func menuWillOpen(_ menu: NSMenu) {
    model.refreshToday()
    let today = model.progress
    todayItem.title = String(
      format: "Today: %.0f min · %.0f avg · %.0f best", today.minutes, today.average, today.best)
    if let hotkey = settings.hotkey {
      practiseItem.keyEquivalent = keyEquivalent(for: hotkey)
      var flags: NSEvent.ModifierFlags = []
      if hotkey.modifiers.contains(.control) { flags.insert(.control) }
      if hotkey.modifiers.contains(.option) { flags.insert(.option) }
      if hotkey.modifiers.contains(.shift) { flags.insert(.shift) }
      if hotkey.modifiers.contains(.command) { flags.insert(.command) }
      practiseItem.keyEquivalentModifierMask = flags
    } else {
      practiseItem.keyEquivalent = ""
    }
  }

  private func keyEquivalent(for hotkey: Hotkey) -> String {
    if hotkey.keyCode == 49 { return " " }
    let special: [UInt16: NSEvent.SpecialKey] = [
      36: .carriageReturn, 48: .tab, 71: .clearLine, 76: .enter, 114: .help,
      115: .home, 116: .pageUp, 117: .deleteForward, 119: .end, 121: .pageDown,
      123: .leftArrow, 124: .rightArrow, 125: .downArrow, 126: .upArrow,
    ]
    if let key = special[hotkey.keyCode] { return String(key.unicodeScalar) }
    if hotkey.keyLabel.hasPrefix("F"), let number = Int(hotkey.keyLabel.dropFirst()) {
      return String(
        NSEvent.SpecialKey(rawValue: NSEvent.SpecialKey.f1.rawValue + number - 1).unicodeScalar)
    }
    return hotkey.keyLabel.lowercased()
  }

  @objc private func practiseAction() { practise() }
  @objc private func progressAction() { progress() }
  @objc private func settingsAction() { openSettings() }
  @objc private func quitAction() { NSApp.terminate(nil) }
}
