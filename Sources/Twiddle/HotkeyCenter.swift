import AppKit
import Carbon
import TwiddleCore

@MainActor
final class HotkeyCenter {
  private enum Failure: Error {
    case carbon(OSStatus)
  }

  private var handler: EventHandlerRef?
  private var hotkey: EventHotKeyRef?
  private var registered: Hotkey?
  private let onHotkey: () -> Void

  init(onHotkey: @escaping () -> Void) { self.onHotkey = onHotkey }

  func replace(with candidate: Hotkey?) -> Bool {
    if candidate == registered { return true }
    do {
      guard let candidate else {
        try unregister()
        return true
      }
      try installHandler()
      var replacement: EventHotKeyRef?
      let registration = RegisterEventHotKey(
        UInt32(candidate.keyCode), candidate.carbonModifiers,
        EventHotKeyID(signature: 0x5457_444C, id: 1), GetApplicationEventTarget(),
        OptionBits(kEventHotKeyExclusive), &replacement)
      guard registration == noErr else { throw Failure.carbon(registration) }
      do {
        try unregister()
      } catch {
        if let replacement {
          let cleanup = UnregisterEventHotKey(replacement)
          if cleanup != noErr { NSLog("Twiddle replacement cleanup failed: %d", cleanup) }
        }
        throw error
      }
      hotkey = replacement
      registered = candidate
      return true
    } catch {
      NSLog("Twiddle hotkey registration failed: %@", String(describing: error))
      return false
    }
  }

  func canRecord(_ candidate: Hotkey) -> Bool {
    // macOS lists the default as its input-source shortcut, yet Carbon registers it and it works.
    guard candidate != .standard else { return true }
    var shortcuts: Unmanaged<CFArray>?
    let status = CopySymbolicHotKeys(&shortcuts)
    guard status == noErr else {
      NSLog("Twiddle symbolic hotkey lookup failed: %d", status)
      return false
    }
    let symbolic = shortcuts?.takeRetainedValue() as? [[String: Any]] ?? []
    return !symbolic.contains {
      ($0[kHISymbolicHotKeyEnabled] as? NSNumber)?.boolValue == true
        && ($0[kHISymbolicHotKeyCode] as? NSNumber)?.uint16Value == candidate.keyCode
        && ($0[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value == candidate.carbonModifiers
    }
  }

  private func installHandler() throws {
    guard handler == nil else { return }
    var event = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        // The application event target dispatches Carbon hotkeys on the main thread.
        MainActor.assumeIsolated {
          Unmanaged<HotkeyCenter>.fromOpaque(context).takeUnretainedValue().onHotkey()
        }
        return noErr
      }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    guard status == noErr else { throw Failure.carbon(status) }
  }

  private func unregister() throws {
    if let hotkey {
      let status = UnregisterEventHotKey(hotkey)
      guard status == noErr else { throw Failure.carbon(status) }
    }
    hotkey = nil
    registered = nil
  }

  func stop() {
    do { try unregister() } catch {
      NSLog("Twiddle hotkey cleanup failed: %@", String(describing: error))
    }
    if let handler {
      let status = RemoveEventHandler(handler)
      if status != noErr { NSLog("Twiddle event handler cleanup failed: %d", status) }
      self.handler = nil
    }
  }
}

extension Hotkey {
  var carbonModifiers: UInt32 {
    var value: UInt32 = 0
    if modifiers.contains(.control) { value |= UInt32(controlKey) }
    if modifiers.contains(.option) { value |= UInt32(optionKey) }
    if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
    if modifiers.contains(.command) { value |= UInt32(cmdKey) }
    return value
  }
}

extension Hotkey.Modifiers {
  init(_ flags: NSEvent.ModifierFlags) {
    self = []
    if flags.contains(.control) { insert(.control) }
    if flags.contains(.option) { insert(.option) }
    if flags.contains(.shift) { insert(.shift) }
    if flags.contains(.command) { insert(.command) }
  }
}
