import Foundation
import Testing
import TwiddleCore

@MainActor
final class SettingsFixture {
  let name = "TwiddleTests.\(UUID().uuidString)"
  let practice = PracticeFixture()
  lazy var defaults = UserDefaults(suiteName: name)!
  lazy var settings = Settings(defaults: defaults)
  lazy var model = PracticeModel(
    store: practice.store, random: FixedRandom(), settings: settings,
    now: { self.practice.time }, date: { self.practice.date })

  func clean() throws {
    defaults.removePersistentDomain(forName: name)
    try practice.clean()
  }
}

@MainActor
struct SettingsTests {
  @Test func firstLaunchDefaults() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    #expect(f.settings.defaultMode == .flow)
    #expect(f.settings.defaultSource == .words)
    #expect(f.settings.mistakes == .strict)
    #expect(f.settings.theme == .system)
    #expect(f.settings.hotkey == .standard)
    f.model.launch()
    #expect(f.model.mode == .flow)
    #expect(f.model.source == .words)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.hotkey?.label == "⌃⌥Space")
  }

  @Test func settingsRoundTripAndClearedShortcut() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.settings.defaultMode = .sprint
    f.settings.defaultSource = .code
    f.settings.mistakes = .forgiving
    f.settings.theme = .dark
    f.settings.hotkey = Hotkey(keyCode: 35, modifiers: [.command, .shift])
    let loaded = Settings(defaults: f.defaults)
    #expect(loaded.defaultMode == .sprint)
    #expect(loaded.defaultSource == .code)
    #expect(loaded.mistakes == .forgiving)
    #expect(loaded.theme == .dark)
    #expect(loaded.hotkey?.label == "⇧⌘P")
    f.settings.hotkey = nil
    #expect(Settings(defaults: f.defaults).hotkey == nil)
    #expect(f.model.hotkey == nil)
  }

  @Test(arguments: ["string", "number", "array", "bool"])
  func corruptValuesUseDefaults(kind: String) throws {
    let value: Any
    switch kind {
    case "string": value = "unknown"
    case "number": value = 999
    case "array": value = ["bad"]
    default: value = true
    }
    let f = SettingsFixture()
    defer { try! f.clean() }
    for key in ["hotkey", "defaultMode", "defaultSource", "mistakes", "theme"] {
      f.defaults.set(value, forKey: key)
    }
    #expect(f.settings.hotkey == .standard)
    #expect(f.settings.defaultMode == .flow)
    #expect(f.settings.defaultSource == .words)
    #expect(f.settings.mistakes == .strict)
    #expect(f.settings.theme == .system)
  }

  @Test(arguments: [-1, 0, 42])
  func invalidSavedSprintLengthFallsBack(length: Int) throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.practice.store.today)
    state.lastSprintLength = length
    try f.practice.store.save(state)
    f.defaults.set(60, forKey: "sprintLength")
    #expect(f.model.sprintLength == 30)
    #expect(f.model.state.lastSprintLength == 30)
    f.model.setSprintLength(5)
    #expect(f.model.state.lastSprintLength == 30)
    f.model.quit()
    #expect(f.practice.store.load().state.lastSprintLength == 30)
    #expect(f.defaults.object(forKey: "sprintLength") == nil)
  }

  @Test func launchWithDefaultSprintIsReadyOnSummon() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.settings.defaultMode = .sprint
    var state = Store.State(date: f.practice.store.today)
    state.seenIntro = true
    try f.practice.store.save(state)
    f.model.launch()
    #expect(!f.model.isVisible)
    f.model.summon()
    #expect(f.model.mode == .sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.stats.run == nil)
  }

  @Test func launchWithDefaultCode() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.settings.defaultSource = .code
    f.model.launch()
    f.model.hide()
    f.model.summon()
    #expect(f.model.source == .code)
    #expect(f.model.session.text.contains("\n"))
    f.settings.defaultSource = .prose
    f.settings.defaultMode = .sprint
    f.model.hide()
    f.model.summon()
    #expect(f.model.source == .code)
    #expect(f.model.mode == .flow)
  }

  @Test func mistakesWaitForNextSummonAndClearPending() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.character("!"))
    #expect(f.model.session.pending == "!")
    f.settings.mistakes = .forgiving
    #expect(f.model.session.mode == .strict)
    #expect(f.model.session.pending == "!")
    f.model.hide()
    f.model.summon()
    #expect(f.model.session.mode == .forgiving)
    #expect(f.model.session.pending == nil)
    f.model.handle(.character("!"))
    #expect(f.model.session.caret == 1)
  }

  @Test func midSprintMistakesStayUntilNextSummon() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    f.model.handle(.character(f.model.session.expected!))
    f.settings.mistakes = .forgiving
    f.model.handle(.character("!"))
    #expect(f.model.sprintState == .running)
    #expect(f.model.session.mode == .strict)
    #expect(f.model.session.caret == 1)
    #expect(f.model.session.pending == "!")
    f.model.hide()
    f.model.summon()
    #expect(f.model.session.mode == .forgiving)
    #expect(f.model.session.pending == nil)
    #expect(f.model.sprintState == .ready)
  }

  @Test func sprintLengthSavedWithoutChangingRunningSprint() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    f.model.handle(.character(f.model.session.expected!))
    f.model.setSprintLength(15)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.state.lastSprintLength == 15)
    #expect(f.practice.store.load().state.lastSprintLength == 15)
    #expect(f.defaults.object(forKey: "sprintLength") == nil)
    f.practice.time = 15
    f.model.tick()
    #expect(f.model.sprintState == .running)
    f.practice.time = 30
    f.model.tick()
    #expect(f.model.sprintState == .locked)
    #expect(f.model.state.runs.first?.activeSeconds == 30)
    f.model.hide()
    f.model.summon()
    #expect(f.model.sprintLength == 15)
    #expect(f.model.sprintRemaining == 15)
  }

  @Test func commandSprintLengthSurvivesRelaunchWithSettings() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.defaults.set(15, forKey: "sprintLength")
    f.model.summon()
    f.model.handle(.sprint)
    f.model.handle(.sprint)
    #expect(f.model.sprintLength == 60)
    #expect(f.model.state.lastSprintLength == 60)
    f.model.quit()
    let settings = Settings(defaults: f.defaults)
    let relaunched = PracticeModel(
      store: f.practice.store, random: FixedRandom(), settings: settings,
      now: { f.practice.time }, date: { f.practice.date })
    #expect(relaunched.state.lastSprintLength == 60)
    #expect(relaunched.sprintLength == 60)
    #expect(f.defaults.object(forKey: "sprintLength") == nil)
    relaunched.summon()
    relaunched.handle(.sprint)
    #expect(relaunched.sprintRemaining == 60)
  }

  @Test func settingsHintsReadAndWriteSavedState() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.setHints(true)
    #expect(f.model.hintsOn)
    #expect(f.practice.store.load().state.hintsOn)
    f.model.summon()
    #expect(f.model.showsHints)
    f.model.handle(.toggleHints)
    #expect(!f.model.hintsOn)
    f.model.handle(.progress)
    f.model.setHints(true)
    #expect(!f.model.showsHints)
    f.model.handle(.progress)
    #expect(f.model.showsHints)
  }

  @Test(arguments: [false, true])
  func menuProgressOpensDirectlyFromAnyMode(sprint: Bool) throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    if sprint { f.settings.defaultMode = .sprint }
    f.model.launch()
    #expect(f.model.view == .intro)
    f.model.openProgress()
    #expect(f.model.isVisible)
    #expect(f.model.view == .progress)
    #expect(f.model.seenIntro)
    f.model.handle(.character(f.model.session.expected!))
    f.model.openProgress()
    #expect(f.model.view == .progress)
    #expect(f.model.stats.run == nil)
    f.model.hide()
    f.model.openProgress()
    #expect(f.model.view == .progress)
  }

  @Test func todayRefreshWorksWhileHidden() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.character(f.model.session.expected!))
    f.model.hide()
    #expect(f.model.progress.average > 0 || f.model.stats.today.presses == 1)
    f.practice.date = f.practice.date.addingTimeInterval(86400)
    f.model.refreshToday()
    #expect(f.model.progress.minutes == 0)
    #expect(f.model.progress.average == 0)
    #expect(f.model.progress.best == 0)
  }

  @Test func panelOffsetSavedAndReset() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.setPanelOffset(.init(x: 120, y: 80))
    #expect(f.practice.store.load().state.panelOffset == .init(x: 120, y: 80))
    f.model.setPanelOffset(.init(x: .nan, y: 0))
    #expect(f.model.state.panelOffset == .init(x: 120, y: 80))
    f.model.setPanelOffset(.init())
    #expect(f.practice.store.load().state.panelOffset == .init())
  }

  @Test func draggedPositionAndSmallerScreenClamp() {
    let screen = PanelLayout.Rect(x: 100, y: 50, width: 1200, height: 800)
    let frame = PanelLayout.position(
      width: 720, height: 136, in: screen,
      offset: .init(x: 120, y: 80), bottom: 40)
    #expect(frame == .init(x: 460, y: 170, width: 720, height: 136))
    #expect(PanelLayout.offset(of: frame, in: screen, bottom: 40) == .init(x: 120, y: 80))
    let small = PanelLayout.Rect(x: 0, y: 0, width: 800, height: 600)
    let clamped = PanelLayout.position(
      width: 720, height: 252, in: small,
      offset: .init(x: 120, y: 900), bottom: 40)
    #expect(clamped == .init(x: 80, y: 348, width: 720, height: 252))
    let reset = PanelLayout.position(
      width: 720, height: 136, in: small, offset: .init(), bottom: 40)
    #expect(reset == .init(x: 40, y: 40, width: 720, height: 136))
    #expect(
      PanelLayout.position(
        width: 720, height: 136, in: small,
        offset: .init(x: .infinity, y: .nan), bottom: 40) == reset)
  }
}
