import Foundation
import Observation

@Observable
@MainActor
public final class Settings {
  public enum Theme: String, CaseIterable, Sendable {
    case system, light, dark
  }

  @ObservationIgnored private let defaults: UserDefaults
  public var hotkey: Hotkey? {
    didSet { defaults.set(hotkey?.stored ?? "", forKey: "hotkey") }
  }
  public var defaultMode: StatsTracker.Mode {
    didSet { defaults.set(defaultMode.rawValue, forKey: "defaultMode") }
  }
  public var defaultSource: ContentProvider.Source {
    didSet { defaults.set(defaultSource.rawValue, forKey: "defaultSource") }
  }
  public var mistakes: TypingSession.MistakeMode {
    didSet { defaults.set(mistakes.rawValue, forKey: "mistakes") }
  }
  public var theme: Theme {
    didSet { defaults.set(theme.rawValue, forKey: "theme") }
  }

  public init(defaults: UserDefaults) {
    self.defaults = defaults
    let savedHotkey = defaults.string(forKey: "hotkey")
    hotkey = savedHotkey == "" ? nil : savedHotkey.flatMap(Hotkey.init(stored:)) ?? .standard
    defaultMode = defaults.string(forKey: "defaultMode").flatMap(StatsTracker.Mode.init) ?? .flow
    defaultSource =
      defaults.string(forKey: "defaultSource").flatMap(ContentProvider.Source.init) ?? .words
    mistakes =
      defaults.string(forKey: "mistakes").flatMap(TypingSession.MistakeMode.init) ?? .strict
    theme = defaults.string(forKey: "theme").flatMap(Theme.init) ?? .system
    defaults.removeObject(forKey: "sprintLength")
  }
}

@Observable
@MainActor
public final class LoginSetting {
  public private(set) var enabled = false
  public private(set) var error: String?
  @ObservationIgnored private let read: () -> Bool
  @ObservationIgnored private let update: (Bool) throws -> Void

  public init(read: @escaping () -> Bool, update: @escaping (Bool) throws -> Void) {
    self.read = read
    self.update = update
    refresh()
  }

  public func refresh() { enabled = read() }

  public func setEnabled(_ value: Bool) {
    error = nil
    do {
      try update(value)
      enabled = read()
      if value && !enabled { error = "Allow Twiddle in System Settings → Login Items." }
    } catch {
      enabled = false
      self.error = error.localizedDescription
    }
  }
}
