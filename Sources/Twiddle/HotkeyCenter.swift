import AppKit
import Carbon

@MainActor
final class HotkeyCenter {
  private enum RegistrationError: Error {
    case carbon(OSStatus)
  }

  private var handler: EventHandlerRef?
  private var hotkey: EventHotKeyRef?
  private let onHotkey: () -> Void

  init(onHotkey: @escaping () -> Void) {
    self.onHotkey = onHotkey
  }

  func start() throws {
    var event = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)
    )
    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        // The application event target dispatches Carbon hotkeys on the main thread.
        MainActor.assumeIsolated {
          Unmanaged<HotkeyCenter>.fromOpaque(context).takeUnretainedValue().onHotkey()
        }
        return noErr
      },
      1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler
    )
    guard handlerStatus == noErr else { throw RegistrationError.carbon(handlerStatus) }

    let hotkeyStatus = RegisterEventHotKey(
      UInt32(kVK_Space), UInt32(controlKey | optionKey),
      EventHotKeyID(signature: 0x5457_444C, id: 1),
      GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotkey
    )
    guard hotkeyStatus == noErr else {
      stop()
      throw RegistrationError.carbon(hotkeyStatus)
    }
  }

  func stop() {
    if let hotkey {
      let status = UnregisterEventHotKey(hotkey)
      if status != noErr { NSLog("Twiddle hotkey cleanup failed: %d", status) }
      self.hotkey = nil
    }
    if let handler {
      let status = RemoveEventHandler(handler)
      if status != noErr { NSLog("Twiddle event handler cleanup failed: %d", status) }
      self.handler = nil
    }
  }
}
