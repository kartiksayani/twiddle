import Foundation
import Testing
import TwiddleCore

@MainActor
struct PanelViewInteractionTests {
  @Test func firstLaunchShowsIntroWithoutSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.launch()
    #expect(f.model.isVisible)
    #expect(f.model.view == .intro)
    #expect(f.model.mode == .flow)
    #expect(f.model.source == .words)
    #expect(f.model.panelHeight == 136)
    f.model.launch()
    #expect(f.model.view == .intro)
  }

  @Test(arguments: [TypingSession.Input.character("a"), .backspace, .deleteWord])
  func introInputTeachesFlowAndSaves(input: TypingSession.Input) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed()
    f.model.launch()
    f.model.handle(input)
    #expect(f.model.view == .text)
    #expect(f.model.mode == .flow)
    #expect(f.model.source == .words)
    #expect(f.store.load().state.seenIntro)
    if case .character = input {
      #expect(f.model.stats.today.presses == 1)
      #expect(f.model.session.caret == 1)
    } else {
      #expect(f.model.stats.today.presses == 0)
    }
  }

  @Test func escapeIntroMarksSeenAndNextSummonIsFlowText() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.launch()
    f.model.hide()
    #expect(!f.model.isVisible)
    #expect(f.store.load().state.seenIntro)
    f.model.summon()
    #expect(f.model.view == .text)
    #expect(f.model.mode == .flow)
  }

  @Test func seenIntroLaunchStaysHidden() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.store.today)
    state.seenIntro = true
    try f.store.save(state)
    f.model.launch()
    #expect(!f.model.isVisible)
    #expect(f.model.session.text.isEmpty)
  }

  @Test func flowProgressKeepsRunUntilHidden() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    let run = try #require(f.model.stats.run)
    f.model.handle(.progress)
    #expect(f.model.view == .progress)
    #expect(f.model.stats.run?.startedAt == run.startedAt)
    #expect(f.model.stats.run?.counters == run.counters)
    #expect(f.model.state.runs.isEmpty)
    f.model.hide()
    #expect(f.model.state.runs.count == 1)
  }

  @Test func sprintReadyAllowsProgress() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    f.model.handle(.progress)
    #expect(f.model.view == .progress)
    #expect(f.model.sprintState == .ready)
  }

  @Test(arguments: [PracticeModel.SprintState.running, .locked, .result])
  func activeSprintRejectsProgress(state: PracticeModel.SprintState) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    f.type(1)
    if state != .running {
      f.time = 30
      f.model.tick()
    }
    if state == .result {
      f.time = 30.6
      f.model.tick()
    }
    #expect(f.model.sprintState == state)
    let counters = f.model.headerCounters
    f.model.handle(.progress)
    #expect(f.model.view == .text)
    #expect(f.model.sprintState == state)
    #expect(f.model.headerCounters == counters)
  }

  @Test func progressShowsKeysTypedSinceLastSave() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(3)
    #expect(f.model.state.keys.isEmpty)
    f.model.handle(.progress)
    #expect(!f.model.state.keys.isEmpty)
  }

  @Test func progressCommandReturnsToText() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.progress)
    f.model.handle(.progress)
    #expect(f.model.view == .text)
  }

  @Test func progressTextCountsFirstKey() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    let caret = f.model.session.caret
    f.model.handle(.progress)
    f.type(1)
    #expect(f.model.view == .text)
    #expect(f.model.session.caret == caret + 1)
    #expect(f.model.stats.today.presses == 1)
  }

  @Test(arguments: [TypingSession.Input.backspace, .deleteWord])
  func progressBackspaceReturnsWithoutEditing(input: TypingSession.Input) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(1)
    f.model.handle(.character("!"))
    let pending = f.model.session.pending
    let counters = f.model.stats.today
    f.model.handle(.progress)
    f.model.handle(input)
    #expect(f.model.view == .text)
    #expect(f.model.session.pending == pending)
    #expect(f.model.stats.today == counters)
  }

  @Test func escapeProgressThenSummonShowsText() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.progress)
    f.model.hide()
    #expect(!f.model.isVisible)
    #expect(f.model.view == .progress)
    f.model.summon()
    #expect(f.model.view == .text)
  }

  @Test(arguments: [PracticeModel.ViewState.text, .progress, .intro])
  func hintsToggleAndSaveInEveryView(view: PracticeModel.ViewState) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    if view == .intro { f.model.launch() } else { f.model.summon() }
    if view == .progress { f.model.handle(.progress) }
    f.model.handle(.toggleHints)
    #expect(f.model.hintsOn)
    #expect(f.store.load().state.hintsOn)
    #expect(f.model.view == view)
    #expect(f.model.showsHints == (view == .text))
    f.model.handle(.toggleHints)
    #expect(!f.store.load().state.hintsOn)
  }

  @Test func hintTracksExpectedKeyCapitalAndSymbol() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.store.today)
    state.resume["words"] = Store.Resume(session: TypingSession(text: "aT( \n"))
    state.hintsOn = true
    try f.store.save(state)
    f.model.summon()
    for character in "aT( \n" {
      let hint = try #require(f.model.hint)
      #expect(hint == FingerMap.resolve(character))
      #expect(!hint.fingerName.isEmpty)
      #expect(!hint.sublabel.isEmpty)
      f.type(1)
    }
  }

  @Test func wrongKeyDoesNotChangeHintOrGrade() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.toggleHints)
    let hint = f.model.hint
    f.model.handle(.character("!"))
    #expect(f.model.hint == hint)
    #expect(f.model.session.caret == 0)
    #expect(f.model.stats.today.presses == 1)
    #expect(f.model.stats.today.correctPresses == 0)
  }

  @Test func hintsStayHiddenInProgressAndReturnWithText() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.toggleHints)
    f.model.handle(.progress)
    #expect(!f.model.showsHints)
    f.model.handle(.toggleHints)
    #expect(!f.model.showsHints)
    #expect(!f.store.load().state.hintsOn)
    f.model.handle(.toggleHints)
    #expect(!f.model.showsHints)
    #expect(f.store.load().state.hintsOn)
    f.model.handle(.progress)
    #expect(f.model.showsHints)
    #expect(f.model.panelHeight == 252)
  }

  @Test func resultHidesHintsUntilTextReturns() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.toggleHints)
    f.model.handle(.sprint)
    f.type(1)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    #expect(!f.model.showsHints)
    #expect(f.model.hintsOn)
    #expect(f.model.panelHeight == 136)
    f.model.handle(.character("\n"))
    #expect(f.model.showsHints)
  }

  @Test func emptyProgressHasZeroValuesAndNoPoints() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.progress)
    #expect(f.model.progress.isEmpty)
    #expect(f.model.progress.minutes == 0)
    #expect(f.model.progress.average == 0)
    #expect(f.model.progress.best == 0)
    #expect(f.model.progress.points.isEmpty)
    #expect(f.model.progress.bestPoint == nil)
    #expect(f.model.progress.averageY.isFinite)
  }

  @Test func oneRunHasOneCenteredPoint() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(runs: 1)
    f.model.summon()
    f.model.handle(.progress)
    let point = try #require(f.model.progress.points.first)
    #expect(f.model.progress.points.count == 1)
    #expect(point.x == 0.5)
    #expect(point.y.isFinite)
    #expect(f.model.progress.bestPoint == point)
  }

  @Test func progressTickResetsNumbersAtMidnight() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(runs: 1, bestWPM: 90)
    f.model.summon()
    f.type(5)
    f.model.handle(.progress)
    #expect(f.model.progress.minutes > 0)
    #expect(f.model.progress.average > 0)
    #expect(f.model.progress.best == 90)
    f.date = f.date.addingTimeInterval(86400)
    f.model.tick()
    #expect(f.model.view == .progress)
    #expect(f.model.progress.minutes == 0)
    #expect(f.model.progress.average == 0)
    #expect(f.model.progress.best == 0)
    #expect(f.model.progress.runs.count == 1)
  }

  @Test func hintsToggleBeforeMidnightTickResetsTodayBeforeSaving() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(5)
    f.date = f.date.addingTimeInterval(86400)
    f.model.handle(.toggleHints)
    #expect(f.model.stats.today == .init())
    #expect(f.store.load().state.today == .init(date: f.store.today))
    #expect(f.store.load().state.hintsOn)
  }
}
