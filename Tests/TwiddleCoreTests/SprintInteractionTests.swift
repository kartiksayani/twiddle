import Foundation
import Testing
import TwiddleCore

@MainActor
struct SprintInteractionTests {
  @Test func flowToSprintUsesLastLengthAndBlankStats() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed()
    f.model.summon()
    f.type(50)
    f.model.handle(.sprint)
    #expect(f.model.mode == .sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.headerCounters == .init())
    #expect(f.model.session.caret == 0)
    #expect(f.model.session.text != f.model.state.resume["words"]?.text)
    #expect(f.model.state.runs.first?.mode == .flow)
    #expect(f.model.state.runs.first?.source == .words)
  }

  @Test func readyCyclesLengthsWithFreshText() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    for length in [60, 15, 30] {
      f.model.handle(.sprint)
      #expect(f.model.sprintLength == length)
      #expect(f.model.sprintState == .ready)
      #expect(f.model.session.caret == 0)
      #expect(f.model.headerCounters.presses == 0)
      #expect(f.store.load().state.lastSprintLength == length)
    }
  }

  @Test func runningSprintCommandCancelsAtSameLength() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.type(10)
    f.model.handle(.sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.session.caret == 0)
    #expect(f.model.stats.run == nil)
    #expect(f.model.state.runs.isEmpty)
    #expect(f.model.stats.today.presses == 10)
  }

  @Test func firstTextKeyStartsAndCountsEvenWhenWrong() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.time = 5
    f.model.handle(.character("!"))
    #expect(f.model.sprintState == .running)
    #expect(f.model.stats.run?.startedAt == 5)
    #expect(f.model.stats.today.presses == 1)
    #expect(f.model.headerCounters.presses == 1)
    #expect(!f.model.caretBlinks)
  }

  @Test func readyBackspaceDoesNotStart() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.model.handle(.backspace)
    f.model.handle(.deleteWord)
    f.model.handle(.character("\n"))
    #expect(f.model.sprintState == .ready)
    #expect(f.model.stats.run == nil)
    #expect(f.model.stats.today.presses == 0)
    #expect(f.model.caretBlinks)
  }

  @Test func clockReachesZeroAndLocks() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.type(1)
    f.time = 12
    f.model.tick()
    #expect(f.model.sprintRemaining == 18)
    #expect(f.model.headerCounters.activeSeconds == 12)
    f.time = 30
    f.model.tick()
    #expect(f.model.sprintState == .locked)
    #expect(f.model.sprintRemaining == 0)
    #expect(f.model.sprintElapsed == 30)
    #expect(f.model.headerCounters.presses == 1)
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.runs == f.model.state.runs)
  }

  @Test func lockedInputIsNotCountedAnywhere() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    lock(f)
    let today = f.model.stats.today
    let keys = f.model.stats.keyStats.keys
    let caret = f.model.session.caret
    f.model.handle(.character("!"))
    f.model.handle(.backspace)
    #expect(f.model.stats.today == today)
    #expect(f.model.stats.keyStats.keys == keys)
    #expect(f.model.session.caret == caret)
    #expect(f.model.session.pending == nil)
  }

  @Test func lateKeyBeforeTickCompletesSprintWithoutCountingKey() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    let today = f.model.stats.today
    let keys = f.model.stats.keyStats.keys
    let pairs = f.model.stats.keyStats.pairs
    let caret = f.model.session.caret
    f.model.handle(.character(f.model.session.expected!))
    #expect(f.model.stats.today == today)
    #expect(f.model.stats.keyStats.keys == keys)
    #expect(f.model.stats.keyStats.pairs == pairs)
    #expect(f.model.session.caret == caret)
    #expect(f.model.sprintState == .locked)
    #expect(f.model.sprintRemaining == 0)
    #expect(f.model.headerCounters.presses == 5)
    expectCompletedOriginalSprint(f)
    f.time = 30.84
    f.model.tick()
    #expect(f.model.sprintState == .locked)
    f.time = 30.86
    f.model.tick()
    #expect(f.model.result?.counters.activeSeconds == 30)
    expectCompletedOriginalSprint(f)
  }

  @Test func hideAfterUntickedDeadlineSavesOriginalSprintOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    f.model.hide()
    #expect(!f.model.isVisible)
    expectCompletedOriginalSprint(f)
    f.model.tick()
    f.model.hide()
    f.model.quit()
    expectCompletedOriginalSprint(f)
  }

  @Test func quitAfterUntickedDeadlineSavesOriginalSprintOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    f.model.quit()
    #expect(!f.model.isVisible)
    expectCompletedOriginalSprint(f)
    f.model.tick()
    f.model.quit()
    expectCompletedOriginalSprint(f)
  }

  @Test(arguments: ContentProvider.Source.allCases)
  func sourceAfterUntickedDeadlineSavesOriginalSprintOnce(source: ContentProvider.Source) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    f.model.handle(.source(source))
    #expect(f.model.source == source)
    #expect(f.model.sprintState == .ready)
    expectCompletedOriginalSprint(f)
    f.model.tick()
    f.model.hide()
    f.model.quit()
    expectCompletedOriginalSprint(f)
  }

  @Test func flowAfterUntickedDeadlineSavesOriginalSprintOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    f.model.handle(.flow)
    #expect(f.model.mode == .flow)
    expectCompletedOriginalSprint(f)
    f.model.tick()
    f.model.hide()
    f.model.quit()
    expectCompletedOriginalSprint(f)
  }

  @Test func sprintAfterUntickedDeadlineSavesOriginalSprintOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    f.model.handle(.sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    expectCompletedOriginalSprint(f)
    f.model.tick()
    f.model.hide()
    f.model.quit()
    expectCompletedOriginalSprint(f)
  }

  @Test func freshTextAfterUntickedDeadlineSavesOriginalSprintOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    expireWithoutTick(f)
    f.model.handle(.freshText)
    #expect(f.model.sprintState == .ready)
    expectCompletedOriginalSprint(f)
    f.model.tick()
    f.model.hide()
    f.model.quit()
    expectCompletedOriginalSprint(f)
  }

  @Test func lockLasts600MillisecondsAndSavesOnceWithBestWPM() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    lock(f)
    let saved = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.runs == f.model.state.runs)
    #expect(f.model.result == nil)
    f.time = 30.599
    f.model.tick()
    #expect(f.model.sprintState == .locked)
    #expect(f.model.result == nil)
    f.time = 30.6
    f.model.tick()
    #expect(f.model.sprintState == .result)
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.state.runs.first?.mode == .sprint)
    #expect(f.model.state.runs.first?.source == .words)
    #expect(f.model.state.runs.first?.activeSeconds == 30)
    #expect(f.model.state.today.bestWPM == f.model.result?.counters.wpm)
    #expect(f.model.result?.slowestPair == nil)
    #expect(try Data(contentsOf: f.directory.appendingPathComponent("state.json")) == saved)
    f.model.tick()
    f.model.hide()
    f.model.quit()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func lockedHideSavesOnceAndSummonGivesFreshReady() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    lock(f)
    let text = f.model.session.text
    f.model.hide()
    #expect(!f.model.isVisible)
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.runs == f.model.state.runs)
    f.model.summon()
    #expect(f.model.mode == .sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.session.text != text)
    #expect(f.model.session.caret == 0)
    #expect(f.model.result == nil)
    #expect(f.model.headerCounters == .init())
    f.time = 30.6
    f.model.tick()
    f.model.hide()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func lockedQuitSavesOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    lock(f)
    f.model.quit()
    #expect(!f.model.isVisible)
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.runs == f.model.state.runs)
    f.time = 30.6
    f.model.tick()
    f.model.quit()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func lockedFlowCommandSavesOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    lock(f)
    f.model.handle(.flow)
    #expect(f.model.mode == .flow)
    #expect(f.model.result == nil)
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.state.runs.first?.mode == .sprint)
    #expect(f.store.load().state.runs == f.model.state.runs)
    f.time = 30.6
    f.model.tick()
    f.model.hide()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func lockedSprintCommandSavesOnce() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    lock(f)
    f.model.handle(.sprint)
    #expect(f.model.mode == .sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.result == nil)
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.runs == f.model.state.runs)
    f.time = 30.6
    f.model.tick()
    f.model.hide()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func resultReturnStartsNewReadyAtSameLength() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    complete(f)
    f.model.handle(.character("\n"))
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.result == nil)
    #expect(f.model.session.caret == 0)
    #expect(f.model.headerCounters == .init())
  }

  @Test func resultLetterIsIgnored() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    complete(f)
    let today = f.model.stats.today
    let caret = f.model.session.caret
    f.model.handle(.character("a"))
    #expect(f.model.sprintState == .result)
    #expect(f.model.stats.today == today)
    #expect(f.model.session.caret == caret)
  }

  @Test func resultFlowReturnsToExactPlaceAndMarks() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed()
    f.model.summon()
    f.model.handle(.character("!"))
    f.type(8)
    let previous = f.model.session
    complete(f)
    f.model.handle(.flow)
    #expect(f.model.mode == .flow)
    #expect(f.model.session.text == previous.text)
    #expect(f.model.session.caret == previous.caret)
    #expect(f.model.session.mistakes == previous.mistakes)
    #expect(f.model.result == nil)
  }

  @Test func resultHideAndSummonGivesFreshReady() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    complete(f)
    f.model.hide()
    f.model.summon()
    #expect(f.model.sprintState == .ready)
    #expect(f.model.session.caret == 0)
    #expect(f.model.result == nil)
    #expect(f.model.state.runs.count == 1)
  }

  @Test func runningHideCancelsButKeepsPressesAndKeys() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.type(20)
    f.model.hide()
    #expect(f.model.state.runs.isEmpty)
    #expect(f.model.stats.run == nil)
    #expect(f.store.load().state.today.presses == 20)
    #expect(!f.store.load().state.keys.isEmpty)
    f.model.summon()
    #expect(f.model.sprintState == .ready)
    #expect(f.model.session.caret == 0)
  }

  @Test func runningQuitCancelsAndSaves() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.type(20)
    f.model.quit()
    #expect(!f.model.isVisible)
    #expect(f.model.stats.run == nil)
    let saved = f.store.load().state
    #expect(saved.runs.isEmpty)
    #expect(saved.today.presses == 20)
    #expect(!saved.keys.isEmpty)
  }

  @Test func readyHideAndSummonIsFresh() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    let old = f.model.session.text
    f.model.hide()
    f.model.summon()
    #expect(f.model.sprintState == .ready)
    #expect(f.model.session.caret == 0)
    #expect(f.model.session.text != old)
  }

  @Test(
    arguments: [PracticeModel.SprintState.ready, .running, .locked, .result],
    ContentProvider.Source.allCases)
  func everySprintStateCanChangeSource(
    state: PracticeModel.SprintState, source: ContentProvider.Source
  ) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    if state != .ready { f.type(1) }
    if state == .locked || state == .result {
      f.time = 30
      f.model.tick()
    }
    if state == .result {
      f.time = 30.6
      f.model.tick()
    }
    f.model.handle(.source(source))
    #expect(f.model.source == source)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.session.caret == 0)
    #expect(f.model.headerCounters.presses == 0)
    #expect(f.model.result == nil)
    #expect(f.model.state.runs.count == (state == .locked || state == .result ? 1 : 0))
  }

  @Test func flowSourceSwitchCapturesRealSourceAndClearsNote() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 7)
    f.model.summon()
    #expect(f.model.resumedWord != nil)
    f.model.handle(.source(.code))
    #expect(f.model.resumedWord == nil)
    f.type(50)
    f.model.handle(.source(.prose))
    #expect(f.model.state.runs.first?.mode == .flow)
    #expect(f.model.state.runs.first?.source == .code)
    #expect(f.model.stats.run == nil)
    #expect(f.model.session.caret == 0)
  }

  @Test func switchingBackToFlowSourceKeepsPlaceAndMarks() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 6, marks: [0])
    f.model.summon()
    f.type(2)
    f.model.handle(.character("x"))
    let previous = f.model.session
    #expect(previous.caret == 8)
    #expect(previous.pending == "x")
    f.model.handle(.source(.code))
    f.type(4)
    f.model.handle(.source(.words))
    #expect(f.model.session.text == previous.text)
    #expect(f.model.session.caret == previous.caret)
    #expect(f.model.session.pending == previous.pending)
    #expect(f.model.session.mistakes == previous.mistakes)
  }

  @Test(arguments: [false, true])
  func hideDropsCachedFlowPositionAndPending(hideInSprint: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 6, marks: [0])
    f.model.summon()
    f.type(2)
    f.model.handle(.character("x"))
    let previous = f.model.session
    #expect(previous.caret == 8)
    #expect(previous.pending == "x")
    #expect(previous.mistakes == [0, 8])
    f.model.handle(.source(.code))
    f.type(2)
    if hideInSprint { f.model.handle(.sprint) }
    f.model.hide()
    f.model.summon()
    if hideInSprint { f.model.handle(.flow) }
    f.model.handle(.source(.words))
    #expect(f.model.session.text == previous.text)
    #expect(f.model.session.caret == 6)
    #expect(f.model.session.pending == nil)
    #expect(f.model.session.mistakes == [0])
  }

  @Test func flowCommandInFlowChangesNothing() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 7)
    f.model.summon()
    let note = f.model.resumedWord
    f.model.handle(.flow)
    #expect(f.model.resumedWord == note)
    #expect(f.model.session.caret == 6)
    #expect(f.model.mode == .flow)
  }

  @Test func flowFreshTextDropsPendingAndContinuesRun() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(5)
    f.model.handle(.character("!"))
    let run = try #require(f.model.stats.run)
    let old = f.model.session.text
    f.model.handle(.freshText)
    #expect(f.model.session.text != old)
    #expect(f.model.session.caret == 0)
    #expect(f.model.session.pending == nil)
    #expect(f.model.session.mistakes.isEmpty)
    #expect(f.model.stats.run?.startedAt == run.startedAt)
    #expect(f.model.stats.run?.counters == run.counters)
    #expect(f.model.state.runs.isEmpty)
  }

  @Test(arguments: [PracticeModel.SprintState.ready, .running, .locked, .result])
  func sprintFreshTextReturnsToReady(state: PracticeModel.SprintState) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    if state != .ready { f.type(1) }
    if state == .locked || state == .result {
      f.time = 30
      f.model.tick()
    }
    if state == .result {
      f.time = 30.6
      f.model.tick()
    }
    f.model.handle(.freshText)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.session.caret == 0)
    #expect(f.model.result == nil)
    #expect(f.model.stats.run == nil)
  }

  @Test func weakKeysFallbackUsesLiveStatsOnNextFreshText() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.store.today)
    for key in ["a", "b", "c", "d", "e"] {
      let samples = key == "e" ? 19 : 20
      state.keys[key] = try JSONDecoder().decode(
        KeyStats.Entry.self,
        from: Data("{\"samples\":\(samples),\"averageMs\":100,\"errorRate\":0}".utf8))
    }
    state.resume["weakKeys"] = Store.Resume(
      session: TypingSession(text: String(repeating: "e", count: 600)))
    try f.store.save(state)
    f.model.summon()
    f.model.handle(.source(.weakKeys))
    #expect(f.model.contentNote == "Not enough data yet")
    f.type(2)
    #expect(f.model.stats.keyStats.weakestKeys.count == 5)
    #expect(f.model.contentNote == "Not enough data yet")
    f.model.handle(.freshText)
    #expect(f.model.contentNote == nil)
    #expect(f.model.session.text.contains(" "))
  }

  @Test func weakKeysWithoutDataServesWordsAndNote() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.source(.weakKeys))
    #expect(f.model.contentNote == "Not enough data yet")
    #expect(f.model.session.text.allSatisfy { $0.isLowercase || $0 == " " })
    #expect(f.model.source.label == "Weak keys")
  }

  @Test func relaunchRestoresAllSourcePlacesAndLengthButStartsFlow() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    for source in ContentProvider.Source.allCases {
      f.model.handle(.source(source))
      f.type(7)
    }
    f.model.handle(.sprint)
    f.model.handle(.sprint)
    f.model.quit()
    let saved = f.store.load().state
    #expect(saved.resume.count == ContentProvider.Source.allCases.count)
    let relaunched = PracticeModel(store: f.store, random: FixedRandom(), now: { f.time })
    relaunched.summon()
    #expect(relaunched.mode == .flow)
    #expect(relaunched.source == .words)
    #expect(relaunched.sprintLength == 60)
    for source in ContentProvider.Source.allCases {
      relaunched.handle(.source(source))
      var expected = try #require(saved.resume[source.rawValue]).session()
      expected.resumeAtWordStart()
      #expect(relaunched.session.text == expected.text)
      #expect(relaunched.session.caret == expected.caret)
      #expect(relaunched.session.mistakes == expected.mistakes)
    }
  }

  @Test func midnightTickResetsTodayWhileSprintFinishesNormally() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.type(5)
    f.date = f.date.addingTimeInterval(86400)
    f.time = 10
    f.model.tick()
    #expect(f.model.stats.today.presses == 0)
    #expect(f.model.headerCounters.presses == 5)
    #expect(f.model.sprintState == .running)
    f.type(1)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    #expect(f.model.sprintState == .result)
    #expect(f.model.result?.counters.presses == 6)
    #expect(f.model.stats.today.presses == 1)
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.today.presses == 1)
  }

  @Test func sprintResultCountsMarkedOffsetsAndQualifiesSlowestPair() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.model.handle(.character("!"))
    f.model.handle(.character("!"))
    f.type(100)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    #expect(f.model.result?.mistakes == 1)
    #expect(f.model.result?.slowestPair != nil)
    #expect(f.model.result?.counters.presses == 102)
    #expect(f.model.result?.counters.netCorrectChars == 100)
  }

  @Test func hiddenCommandsAreIgnored() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.handle(.sprint)
    f.model.handle(.source(.code))
    f.model.handle(.freshText)
    #expect(f.model.mode == .flow)
    #expect(f.model.source == .words)
    #expect(f.model.session.text.isEmpty)
  }

  @Test(arguments: [15, 30, 60]) func eachLengthCompletesWithRealSource(length: Int) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.store.today)
    state.lastSprintLength = length
    try f.store.save(state)
    f.model.summon()
    f.model.handle(.source(.code))
    f.model.handle(.sprint)
    f.time = 100
    f.type(5)
    f.time = 100 + Double(length)
    f.model.handle(.character("!"))
    #expect(f.model.stats.today.presses == 5)
    f.model.tick()
    f.time += 0.6
    f.model.tick()
    #expect(f.model.sprintState == .result)
    #expect(f.model.result?.counters.activeSeconds == Double(length))
    #expect(f.model.state.runs.first?.mode == .sprint)
    #expect(f.model.state.runs.first?.source == .code)
    #expect(f.model.state.runs.first?.startedAt == f.date.addingTimeInterval(100))
  }

  @Test func currentFlowSourceCommandChangesNothing() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 7)
    f.model.summon()
    let note = f.model.resumedWord
    f.model.handle(.source(.words))
    #expect(f.model.resumedWord == note)
    #expect(f.model.session.caret == 6)
    #expect(f.model.source == .words)
    #expect(f.model.stats.run == nil)
  }

  @Test func unsupportedSavedSprintLengthUses30Seconds() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.store.today)
    state.lastSprintLength = 42
    try f.store.save(state)
    start(f)
    #expect(f.model.sprintLength == 30)
  }

  private func start(_ f: PracticeFixture) {
    f.model.summon()
    if f.model.mode == .flow { f.model.handle(.sprint) }
  }

  private func expireWithoutTick(_ f: PracticeFixture) {
    f.model.summon()
    f.model.handle(.source(.code))
    f.model.handle(.sprint)
    f.type(5)
    f.time = 30.25
    #expect(f.model.sprintState == .running)
    #expect(f.model.state.runs.isEmpty)
  }

  private func expectCompletedOriginalSprint(_ f: PracticeFixture) {
    #expect(f.model.stats.run == nil)
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.state.runs.first?.mode == .sprint)
    #expect(f.model.state.runs.first?.source == .code)
    #expect(f.model.state.runs.first?.startedAt == f.date)
    #expect(f.model.state.runs.first?.activeSeconds == 30)
    #expect(f.model.state.runs.first?.chars == 5)
    #expect(f.store.load().state.runs == f.model.state.runs)
  }

  private func lock(_ f: PracticeFixture) {
    start(f)
    f.type(1)
    f.time = 30
    f.model.tick()
  }

  private func complete(_ f: PracticeFixture) {
    lock(f)
    f.time = 30.6
    f.model.tick()
  }
}
