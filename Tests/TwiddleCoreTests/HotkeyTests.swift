import Foundation
import Testing
import TwiddleCore

struct HotkeyTests {
  @Test func parsingValidationAndLabels() throws {
    #expect(Hotkey.standard.label == "⌃⌥Space")
    #expect(Hotkey(stored: Hotkey.standard.stored) == .standard)
    let all = try #require(Hotkey(keyCode: 0, modifiers: [.control, .option, .shift, .command]))
    #expect(all.parts == ["⌃", "⌥", "⇧", "⌘", "A"])
    #expect(Hotkey(keyCode: 64, modifiers: .option)?.label == "⌥F17")
    #expect(Hotkey(keyCode: 117, modifiers: .control)?.label == "⌃⌦")
    #expect(Hotkey(keyCode: 49, modifiers: []) == nil)
    #expect(Hotkey(keyCode: 49, modifiers: .shift) == nil)
    #expect(Hotkey(keyCode: 49, modifiers: .init(rawValue: 255)) == nil)
    #expect(Hotkey(keyCode: 255, modifiers: .command) == nil)
    #expect(Hotkey(keyCode: 56, modifiers: .command) == nil)
  }

  @Test(arguments: ["", "1", "1:2:3", ":49", "-1:49", "256:49", "1:65536", "0:49", "1:53", "junk"])
  func rejectsCorruptStoredChord(_ stored: String) { #expect(Hotkey(stored: stored) == nil) }
}

@MainActor
struct RecorderTests {
  @Test(arguments: [Hotkey.standard, Hotkey(keyCode: 35, modifiers: .command)!])
  func symbolicConflictCheckedOnlyWhileRecording(shortcut: Hotkey) throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.settings.hotkey = shortcut
    var checked: [Hotkey] = []
    var registrations: [Hotkey?] = []
    let recorder = HotkeyRecorder(
      settings: f.settings,
      canRecord: {
        checked.append($0)
        return false
      },
      register: {
        registrations.append($0)
        return true
      })
    recorder.registerSaved()
    #expect(checked.isEmpty)
    #expect(registrations == [shortcut])
    #expect(recorder.state == .idle)
    recorder.begin()
    recorder.capture(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    #expect(checked == [shortcut])
    #expect(registrations == [shortcut])
    #expect(recorder.state == .conflict(shortcut))
    #expect(f.settings.hotkey == shortcut)
    recorder.clear()
    #expect(checked == [shortcut])
    #expect(registrations == [shortcut, nil])
    #expect(f.settings.hotkey == nil)
  }

  @Test func validChordRegistersAndSaves() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    var registered: Hotkey? = .standard
    let recorder = HotkeyRecorder(settings: f.settings) {
      registered = $0
      return true
    }
    recorder.begin()
    recorder.capture(keyCode: 35, modifiers: .command)
    #expect(recorder.state == .idle)
    #expect(registered == f.settings.hotkey)
    #expect(recorder.label == "⌘P")
    #expect(f.model.hotkey?.label == "⌘P")
    #expect(Settings(defaults: f.defaults).hotkey == registered)
  }

  @Test func missingRequiredModifierKeepsRecording() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    var called = false
    let recorder = HotkeyRecorder(settings: f.settings) { _ in
      called = true
      return true
    }
    recorder.begin()
    recorder.capture(keyCode: 0, modifiers: .shift)
    #expect(recorder.state == .recording)
    #expect(recorder.invalidChord)
    #expect(!called)
    #expect(f.settings.hotkey == .standard)
    recorder.capture(keyCode: 0, modifiers: .option)
    #expect(recorder.state == .idle)
    #expect(!recorder.invalidChord)
  }

  @Test func escapeCancelsAndIdleIgnoresInput() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    var called = false
    let recorder = HotkeyRecorder(settings: f.settings) { _ in
      called = true
      return true
    }
    recorder.capture(keyCode: 0, modifiers: .command)
    recorder.begin()
    recorder.capture(keyCode: 53, modifiers: [])
    #expect(recorder.state == .idle)
    #expect(!called)
    #expect(f.settings.hotkey == .standard)
  }

  @Test func backspaceClearsAndSavesNoHotkey() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    var registered: Hotkey? = .standard
    let recorder = HotkeyRecorder(settings: f.settings) {
      registered = $0
      return true
    }
    recorder.begin()
    recorder.capture(keyCode: 51, modifiers: [])
    #expect(recorder.state == .idle)
    #expect(registered == nil)
    #expect(f.settings.hotkey == nil)
    #expect(Settings(defaults: f.defaults).hotkey == nil)
    #expect(recorder.label == "Record shortcut")
    f.model.summon()
    #expect(f.model.isVisible)
  }

  @Test func conflictKeepsPreviousShortcutAndCanRetry() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    var registered: Hotkey? = .standard
    var succeeds = false
    let recorder = HotkeyRecorder(settings: f.settings) { candidate in
      guard succeeds else { return false }
      registered = candidate
      return true
    }
    recorder.begin()
    recorder.capture(keyCode: 49, modifiers: .option)
    #expect(recorder.state == .conflict(Hotkey(keyCode: 49, modifiers: .option)!))
    #expect(recorder.label == "⌥Space")
    #expect(registered == .standard)
    #expect(f.settings.hotkey == .standard)
    recorder.begin()
    recorder.capture(keyCode: 53, modifiers: [])
    #expect(recorder.state == .idle)
    #expect(recorder.label == Hotkey.standard.label)
    recorder.begin()
    succeeds = true
    recorder.capture(keyCode: 0, modifiers: .command)
    #expect(recorder.label == "⌘A")
    #expect(registered == f.settings.hotkey)
  }

  @Test func launchConflictDoesNotPreventPractice() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    let recorder = HotkeyRecorder(settings: f.settings) { _ in false }
    recorder.registerSaved()
    #expect(recorder.state == .conflict(.standard))
    #expect(f.settings.hotkey == .standard)
    recorder.begin()
    recorder.capture(keyCode: 53, modifiers: [])
    #expect(recorder.state == .conflict(.standard))
    f.model.summon()
    #expect(f.model.isVisible)
  }

  @Test func launchClearedShortcutAndFailedClear() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.settings.hotkey = nil
    let recorder = HotkeyRecorder(settings: f.settings) { _ in false }
    recorder.registerSaved()
    #expect(recorder.state == .idle)
    let working = HotkeyRecorder(settings: f.settings) { _ in true }
    working.registerSaved()
    #expect(working.state == .idle)
    f.settings.hotkey = .standard
    recorder.clear()
    #expect(f.settings.hotkey == .standard)
  }
}

@MainActor
struct LoginSettingTests {
  private struct Failure: Error {}

  @Test func failedUnregisterStaysOnAndShowsError() {
    let login = LoginSetting(read: { true }, update: { _ in throw Failure() })
    login.setEnabled(false)
    #expect(login.enabled)
    #expect(login.error != nil)
  }

  @Test func readsServiceAndRegistersAndUnregisters() {
    var service = true
    let login = LoginSetting(read: { service }, update: { service = $0 })
    #expect(login.enabled)
    login.setEnabled(false)
    #expect(!login.enabled)
    login.setEnabled(true)
    #expect(login.enabled)
    #expect(login.error == nil)
    service = false
    login.refresh()
    #expect(!login.enabled)
  }

  @Test func registrationFailureShowsErrorAndLeavesOff() {
    var fails = true
    var service = false
    let login = LoginSetting(
      read: { service },
      update: { value in
        if fails {
          throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Denied"])
        }
        service = value
      })
    login.setEnabled(true)
    #expect(!login.enabled)
    #expect(login.error == "Denied")
    fails = false
    login.setEnabled(true)
    #expect(login.enabled)
    #expect(login.error == nil)
  }

  @Test func pendingApprovalStaysOffWithExplanation() {
    let login = LoginSetting(read: { false }, update: { _ in })
    login.setEnabled(true)
    #expect(!login.enabled)
    #expect(login.error?.contains("Login Items") == true)
  }
}
