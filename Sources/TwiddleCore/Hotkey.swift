import Foundation
import Observation

public struct Hotkey: Equatable, Sendable {
  public struct Modifiers: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1)
    public static let option = Self(rawValue: 2)
    public static let shift = Self(rawValue: 4)
    public static let command = Self(rawValue: 8)
  }

  public let keyCode: UInt16
  public let modifiers: Modifiers
  public static let standard = Hotkey(keyCode: 49, modifiers: [.control, .option])!

  public init?(keyCode: UInt16, modifiers: Modifiers) {
    guard modifiers.rawValue & 0xF0 == 0,
      !modifiers.intersection([.control, .option, .command]).isEmpty,
      Self.keyLabels[keyCode] != nil
    else { return nil }
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public init?(stored: String) {
    let parts = stored.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, let modifiers = UInt8(parts[0]), let code = UInt16(parts[1])
    else { return nil }
    self.init(keyCode: code, modifiers: Modifiers(rawValue: modifiers))
  }

  public var stored: String { "\(modifiers.rawValue):\(keyCode)" }
  public var keyLabel: String { Self.keyLabels[keyCode]! }
  public var parts: [String] {
    let symbols: [(Modifiers, String)] = [
      (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
    ]
    return symbols.compactMap { modifiers.contains($0.0) ? $0.1 : nil } + [keyLabel]
  }
  public var label: String { parts.joined() }

  // Virtual keys keep the saved chord stable on the v1 QWERTY keyboard.
  private static let keyLabels: [UInt16: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
    11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
    20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
    29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
    38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
    47: ".", 48: "⇥", 49: "Space", 50: "`", 64: "F17", 65: ".", 67: "*", 69: "+", 71: "⌧",
    75: "/", 76: "⌅", 78: "-", 79: "F18", 80: "F19", 81: "=", 82: "0", 83: "1", 84: "2",
    85: "3", 86: "4", 87: "5", 88: "6", 90: "F20",
    89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
    101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
    113: "F15", 114: "Help", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4",
    119: "↘", 120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
  ]
}

@Observable
@MainActor
public final class HotkeyRecorder {
  public enum State: Equatable {
    case idle, recording
    case conflict(Hotkey)
  }

  public private(set) var state: State = .idle
  public private(set) var invalidChord = false
  public let settings: Settings
  @ObservationIgnored private let canRecord: (Hotkey) -> Bool
  @ObservationIgnored private let register: (Hotkey?) -> Bool
  @ObservationIgnored private var savedConflict: Hotkey?

  public init(
    settings: Settings, canRecord: @escaping (Hotkey) -> Bool = { _ in true },
    register: @escaping (Hotkey?) -> Bool
  ) {
    self.settings = settings
    self.canRecord = canRecord
    self.register = register
  }

  public var label: String {
    if case .conflict(let hotkey) = state { return hotkey.label }
    return settings.hotkey?.label ?? "Record shortcut"
  }

  public func registerSaved() {
    if register(settings.hotkey) {
      finish()
    } else if let hotkey = settings.hotkey {
      savedConflict = hotkey
      state = .conflict(hotkey)
    }
  }

  public func begin() {
    invalidChord = false
    state = .recording
  }

  public func cancel() {
    invalidChord = false
    state = savedConflict.map(State.conflict) ?? .idle
  }

  public func clear() {
    guard register(nil) else { return }
    settings.hotkey = nil
    finish()
  }

  public func capture(keyCode: UInt16, modifiers: Hotkey.Modifiers) {
    guard state == .recording else { return }
    if keyCode == 53 {
      cancel()
      return
    }
    if keyCode == 51 {
      clear()
      return
    }
    guard let candidate = Hotkey(keyCode: keyCode, modifiers: modifiers) else {
      invalidChord = true
      return
    }
    guard canRecord(candidate), register(candidate) else {
      state = .conflict(candidate)
      return
    }
    settings.hotkey = candidate
    finish()
  }

  private func finish() {
    savedConflict = nil
    cancel()
  }
}
