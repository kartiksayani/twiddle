import Foundation
import Testing
import TwiddleCore

@MainActor
struct PasteInteractionTests {
  enum Row: CaseIterable {
    case flow, pastedFlow, sprintReady, sprintRunning, sprintResult, progress, intro
  }

  private let original = "Original clipboard text for typing practice."
  private let replacement = "Replacement clipboard text for another practice."
  private let note = "Nothing to practise in the clipboard"

  @Test(arguments: Row.allCases)
  func usableClipboard(row: Row) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    prepare(f, row: row)
    let old = f.model.session
    let state = f.model.state
    let today = f.model.stats.today
    f.model.paste(replacement)
    if row == .intro {
      #expect(f.model.view == .intro)
      #expect(f.model.session.text == old.text)
      #expect(f.model.state == state)
      #expect(f.model.contentNote == nil)
      return
    }
    #expect(f.model.source == .pasted)
    #expect(f.model.sourceLabel == "Pasted")
    #expect(f.model.session.text == replacement + "\n")
    #expect(f.model.session.caret == 0)
    #expect(f.model.session.mistakes.isEmpty)
    #expect(f.model.session.pending == nil)
    #expect(f.model.view == .text)
    #expect(f.model.result == nil)
    #expect(f.model.contentNote == nil)
    #expect(f.model.resumedWord == nil)
    #expect(f.model.stats.run == nil)
    #expect(f.model.stats.today == today)
    #expect(f.model.characters == Array(f.model.session.text))
    #expect(f.model.lines == TextLayout.layout(f.model.session.text))
    if [.sprintReady, .sprintRunning, .sprintResult].contains(row) {
      #expect(f.model.mode == .sprint)
      #expect(f.model.sprintState == .ready)
      #expect(f.model.sprintElapsed == 0)
      #expect(f.model.headerCounters.presses == 0)
    } else {
      #expect(f.model.mode == .flow)
    }
    if row == .flow || row == .pastedFlow || row == .progress {
      #expect(f.model.state.runs.count == 1)
      #expect(f.model.state.runs[0].source == (row == .pastedFlow ? .pasted : .words))
    } else {
      #expect(f.model.state.runs == state.runs)
    }
  }

  @Test(arguments: Row.allCases, [nil, " \t🐈 ", "too short"] as [String?])
  func unusableClipboard(row: Row, input: String?) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    prepare(f, row: row)
    let old = f.model.session
    let view = f.model.view
    let source = f.model.source
    let sprint = f.model.sprintState
    let result = f.model.result
    let state = f.model.state
    let run = f.model.stats.run
    f.model.paste(input)
    #expect(f.model.view == view)
    #expect(f.model.source == source)
    #expect(f.model.session.text == old.text)
    #expect(f.model.session.caret == old.caret)
    #expect(f.model.session.pending == old.pending)
    #expect(f.model.session.mistakes == old.mistakes)
    #expect(f.model.sprintState == sprint)
    #expect(f.model.result?.counters == result?.counters)
    #expect(f.model.stats.run?.startedAt == run?.startedAt)
    #expect(f.model.state == state)
    #expect(f.model.contentNote == (row == .intro ? nil : note))
    if row == .progress {
      f.model.handle(.progress)
      #expect(f.model.view == .text)
      #expect(f.model.contentNote == note)
    }
    if row == .sprintRunning {
      f.time += 0.5
      f.model.tick()
      #expect(f.model.sprintState == .running)
      #expect(f.model.sprintElapsed > 0)
    }
  }

  @Test(arguments: Row.allCases)
  func hideAndSummon(row: Row) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    prepare(f, row: row)
    if row != .intro { f.model.paste(original) }
    f.type(row == .intro ? 0 : 8)
    let old = f.model.session
    f.model.hide()
    f.model.summon()
    #expect(f.model.view == .text)
    #expect(f.model.result == nil)
    if [.sprintReady, .sprintRunning, .sprintResult].contains(row) {
      #expect(f.model.sprintState == .ready)
      #expect(f.model.session.caret == 0)
      #expect(f.model.stats.run == nil)
      #expect(f.model.session.text == original + "\n")
    } else if row != .intro {
      var resumed = old
      resumed.resumeAtWordStart()
      #expect(f.model.source == .pasted)
      #expect(f.model.session.text.hasPrefix(old.text))
      #expect(f.model.session.caret == resumed.caret)
      #expect(f.model.session.pending == nil)
    } else {
      #expect(f.model.seenIntro)
      #expect(f.model.source == .words)
    }
  }

  @Test(arguments: Row.allCases)
  func relaunchUsesDefaultSource(row: Row) throws {
    let f = PracticeFixture()
    let settings = SettingsFixture()
    defer {
      try! f.clean()
      try! settings.clean()
    }
    prepare(f, row: row)
    f.model.paste(original)
    f.model.quit()
    settings.settings.defaultSource = .symbols
    let relaunched = PracticeModel(
      store: f.store, random: FixedRandom(), settings: settings.settings)
    relaunched.summon()
    #expect(relaunched.source == .symbols)
    #expect(!relaunched.session.text.contains(original))
  }

  @Test func loopExtensionAndFreshTextUseOnlyTheNormalizedPaste() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.paste("“Exact text”\tfor practice — on a loop.")
    let loop = "\"Exact text\"    for practice - on a loop.\n"
    #expect(f.model.session.text == loop)
    f.type(450)
    #expect(f.model.session.text.count > 450)
    #expect(
      f.model.session.text
        == String(repeating: loop, count: f.model.session.text.count / loop.count))
    #expect(f.model.lines == TextLayout.layout(f.model.session.text))
    f.model.handle(.freshText)
    #expect(f.model.session.text == loop)
    #expect(f.model.session.caret == 0)
  }

  @Test func modeSwitchAndHideKeepFlowPasteInMemoryAndApplyMistakeMode() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.paste(original)
    for _ in 0..<12 { f.model.handle(.character(f.model.session.expected!)) }
    let flow = f.model.session
    f.model.handle(.sprint)
    f.model.handle(.flow)
    #expect(f.model.session.text == flow.text)
    #expect(f.model.session.caret == flow.caret)
    f.model.handle(.character("!"))
    f.settings.mistakes = .forgiving
    f.model.hide()
    f.model.summon()
    #expect(f.model.session.mode == .forgiving)
    #expect(f.model.session.pending == nil)
    var expected = flow
    expected.resumeAtWordStart()
    #expect(f.model.session.caret == expected.caret)
  }

  @Test func leavingPastedRequiresAnotherPasteToSelectItAgain() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.paste(original)
    f.model.handle(.source(.symbols))
    let text = f.model.session.text
    f.model.handle(.source(.pasted))
    #expect(f.model.source == .symbols)
    #expect(f.model.session.text == text)
    f.model.paste(replacement)
    #expect(f.model.session.text == replacement + "\n")
  }

  @Test func hiddenPasteIsIgnored() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.paste(original)
    #expect(f.model.session.text.isEmpty)
    #expect(f.model.source == .words)
    #expect(f.model.state.resume.isEmpty)
  }

  @Test(arguments: [false, true])
  func pasteAtUntickedSprintDeadlineSavesTheCompletedRunOnce(usable: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.paste(original)
    f.model.handle(.sprint)
    f.type(10)
    f.time = 30
    f.model.paste(usable ? replacement : nil)
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.state.runs[0].source == .pasted)
    #expect(f.model.sprintState == (usable ? .ready : .locked))
    f.time = 31
    f.model.tick()
    #expect(f.model.sprintState == (usable ? .ready : .result))
    f.model.hide()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func pastedCannotBeTheDefaultOrAProvidedCorpus() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    #expect(!ContentProvider.Source.defaultSources.contains(.pasted))
    f.defaults.set("pasted", forKey: "defaultSource")
    #expect(f.settings.defaultSource == .words)
    f.settings.defaultSource = .symbols
    f.settings.defaultSource = .pasted
    #expect(f.settings.defaultSource == .symbols)
    #expect(Settings(defaults: f.defaults).defaultSource == .symbols)
    var random = FixedRandom()
    #expect(ContentProvider().content(for: .pasted, using: &random).text.isEmpty)
  }

  private func prepare(_ f: PracticeFixture, row: Row) {
    if row == .intro {
      f.model.launch()
      return
    }
    f.model.summon()
    if row == .pastedFlow { f.model.paste(original) }
    if [.sprintReady, .sprintRunning, .sprintResult].contains(row) {
      f.model.handle(.sprint)
      if row != .sprintReady { f.type(10) }
      if row == .sprintResult {
        f.time = 30
        f.model.tick()
        f.time = 30.6
        f.model.tick()
      }
    } else {
      f.type(50)
    }
    if row == .progress { f.model.handle(.progress) }
  }
}
