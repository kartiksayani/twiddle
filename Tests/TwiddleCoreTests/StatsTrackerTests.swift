import Testing
import TwiddleCore

func enginePress(_ key: Character = "a", correct: Bool = true) -> TypingSession.Change {
  var session = TypingSession(text: String(key))
  return session.handle(.character(correct ? key : "!"))
}

struct StatsTrackerTests {
  @Test func gapUnderTenSecondsAddsActiveTime() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    tracker.record(enginePress(), at: 9.999)
    #expect(tracker.today.activeSeconds == 9.999)
    #expect(tracker.run?.counters.activeSeconds == 9.999)
    #expect(tracker.today.netCorrectChars == 2)
    #expect(tracker.today.presses == 2)
    #expect(tracker.today.correctPresses == 2)
  }

  @Test(arguments: [10.0, 10.001, 299.0])
  func tenSecondsAndLongerAreExcludedAndPaused(gap: Double) {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    #expect(!tracker.isPaused(at: 9.999))
    #expect(tracker.isPaused(at: gap))
    tracker.record(enginePress(), at: gap)
    #expect(tracker.today.activeSeconds == 0)
    #expect(tracker.run?.counters.activeSeconds == 0)
    #expect(!tracker.isPaused(at: gap))
    tracker.record(enginePress(), at: gap + 1)
    #expect(tracker.today.activeSeconds == 1)
  }

  @Test func firstPressAddsNoGap() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 1234)
    #expect(tracker.today.activeSeconds == 0)
    #expect(tracker.run?.startedAt == 1234)
    #expect(tracker.today.wpm == 0)
    #expect(tracker.today.accuracy == 1)
  }

  @Test func emptyCountersAndReadySprintAreDefined() {
    let tracker = StatsTracker(mode: .sprint)
    #expect(tracker.today.wpm == 0)
    #expect(tracker.today.accuracy == 0)
    #expect(tracker.currentCounters(at: 100) == nil)
    #expect(!tracker.isPaused(at: 100))
  }

  @Test func forgivingCorrectionsUseNetForWPMAndPressesForAccuracy() {
    var session = TypingSession(text: "abc", mode: .forgiving)
    var tracker = StatsTracker()
    tracker.record(session.handle(.character("a")), at: 0)
    tracker.record(session.handle(.character("x")), at: 1)
    tracker.record(session.handle(.backspace), at: 1.1)
    tracker.record(session.handle(.character("b")), at: 2)
    tracker.record(session.handle(.backspace), at: 2.1)
    tracker.record(session.handle(.character("b")), at: 3)
    #expect(tracker.today.netCorrectChars == 2)
    #expect(tracker.today.presses == 4)
    #expect(tracker.today.correctPresses == 3)
    #expect(tracker.today.activeSeconds == 3)
    #expect(tracker.today.wpm == 8)
    #expect(tracker.today.accuracy == 0.75)
    #expect(tracker.run?.counters == tracker.today)
  }

  @Test func runExpiresAtFiveIdleMinutes() throws {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 10)
    #expect(tracker.update(at: 309.999) == nil)
    let expired = tracker.update(at: 310)
    let ended = try #require(expired)
    #expect(ended.counters.netCorrectChars == 1)
    #expect(!ended.shouldSave)
    #expect(tracker.run == nil)
    #expect(tracker.isPaused(at: 310))
    #expect(tracker.update(at: 600) == nil)
    #expect(tracker.isPaused(at: 600))
    #expect(tracker.today.netCorrectChars == 1)
  }

  @Test func pressAfterFiveIdleMinutesEndsOldRunAndStartsNewOne() throws {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    let expired = tracker.record(enginePress(), at: 301)
    let ended = try #require(expired)
    #expect(ended.startedAt == 0)
    #expect(ended.counters.presses == 1)
    #expect(tracker.run?.startedAt == 301)
    #expect(tracker.run?.counters.presses == 1)
    #expect(tracker.today.presses == 2)
    #expect(tracker.today.activeSeconds == 0)
    #expect(tracker.keyStats.keys["a"]?.samples == 0)
  }

  @Test func shortRunStillFeedsTodayAndKeys() throws {
    var tracker = StatsTracker()
    for index in 0..<10 { tracker.record(enginePress(), at: Double(index) * 0.1) }
    let result = tracker.endRun(at: 1)
    let ended = try #require(result)
    #expect(!ended.shouldSave)
    #expect(ended.counters.netCorrectChars == 10)
    #expect(tracker.today.netCorrectChars == 10)
    #expect(tracker.keyStats.keys["a"]?.samples == 9)
    #expect(tracker.run == nil)
    #expect(tracker.endRun(at: 2) == nil)
  }

  @Test(arguments: [49, 50])
  func flowSaveThresholdIsNetCharacters(count: Int) throws {
    var tracker = StatsTracker()
    for index in 0..<count { tracker.record(enginePress(), at: Double(index) * 0.1) }
    let result = tracker.endRun(at: 10)
    let ended = try #require(result)
    #expect(ended.shouldSave == (count >= 50))
  }

  @Test func correctionsCanPutRunBackBelowSaveThreshold() throws {
    var session = TypingSession(text: String(repeating: "a", count: 50), mode: .forgiving)
    var tracker = StatsTracker()
    for index in 0..<50 {
      tracker.record(session.handle(.character("a")), at: Double(index) * 0.1)
    }
    tracker.record(session.handle(.backspace), at: 5)
    let result = tracker.endRun(at: 6)
    let ended = try #require(result)
    #expect(ended.counters.presses == 50)
    #expect(ended.counters.netCorrectChars == 49)
    #expect(!ended.shouldSave)
  }

  @Test func hideBreaksTimingSequenceButPreservesTotals() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    tracker.endRun(at: 0.1)
    tracker.record(enginePress(), at: 0.2)
    #expect(tracker.today.presses == 2)
    #expect(tracker.today.activeSeconds == 0)
    #expect(tracker.keyStats.keys["a"]?.samples == 0)
    #expect(tracker.run?.counters.presses == 1)
  }

  @Test(arguments: [false, true], [false, true])
  func explicitRunEndClearsPausedState(isSprint: Bool, completed: Bool) {
    var tracker = StatsTracker(mode: isSprint ? .sprint : .flow)
    tracker.record(enginePress(), at: 0)
    #expect(tracker.isPaused(at: 10))
    tracker.endRun(at: 10, completed: completed)
    #expect(!tracker.isPaused(at: 100))
    tracker.record(enginePress(), at: 101)
    #expect(!tracker.isPaused(at: 101))
    #expect(tracker.today.activeSeconds == 0)
    #expect(tracker.keyStats.keys["a"]?.samples == 0)
  }

  @Test func hideAfterIdleExpiryClearsPausedStateWithoutCurrentRun() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    tracker.update(at: 300)
    #expect(tracker.isPaused(at: 300))
    #expect(tracker.endRun(at: 301) == nil)
    #expect(!tracker.isPaused(at: 400))
  }

  @Test(arguments: [false, true])
  func modeChangeClearsPausedState(isSprint: Bool) throws {
    let mode: StatsTracker.Mode = isSprint ? .sprint : .flow
    var tracker = StatsTracker(mode: mode)
    tracker.record(enginePress(), at: 0)
    #expect(tracker.isPaused(at: 10))
    let result = tracker.setMode(mode == .flow ? .sprint : .flow, at: 10)
    let ended = try #require(result)
    #expect(ended.mode == mode)
    #expect(ended.counters.presses == 1)
    #expect(!ended.shouldSave)
    #expect(tracker.run == nil)
    #expect(!tracker.isPaused(at: 100))
  }

  @Test func todayAndKeyStatsSurviveFlowToSprintToFlow() throws {
    var tracker = StatsTracker()
    for index in 0..<3 { tracker.record(enginePress(), at: Double(index) * 0.25) }
    let flowToday = tracker.today
    let flowKeys = tracker.keyStats.keys
    let flowPairs = tracker.keyStats.pairs
    let flowResult = tracker.setMode(.sprint, at: 0.75)
    let flow = try #require(flowResult)
    #expect(flow.mode == .flow)
    #expect(flow.counters == flowToday)
    #expect(tracker.mode == .sprint)
    #expect(tracker.today == flowToday)
    #expect(tracker.keyStats.keys == flowKeys)
    #expect(tracker.keyStats.pairs == flowPairs)

    for index in 0..<3 { tracker.record(enginePress(), at: 1 + Double(index) * 0.25) }
    #expect(tracker.today.presses == 6)
    #expect(tracker.today.correctPresses == 6)
    #expect(tracker.today.netCorrectChars == 6)
    #expect(tracker.today.activeSeconds == 1)
    #expect(tracker.keyStats.keys["a"]?.samples == 4)
    let sprintToday = tracker.today
    let sprintKeys = tracker.keyStats.keys
    let sprintPairs = tracker.keyStats.pairs
    let sprintResult = tracker.setMode(.flow, at: 1.75)
    let sprint = try #require(sprintResult)
    #expect(sprint.mode == .sprint)
    #expect(sprint.counters.presses == 3)
    #expect(sprint.counters.activeSeconds == 0.75)
    #expect(!sprint.shouldSave)
    #expect(tracker.mode == .flow)
    #expect(tracker.today == sprintToday)
    #expect(tracker.keyStats.keys == sprintKeys)
    #expect(tracker.keyStats.pairs == sprintPairs)

    tracker.record(enginePress(), at: 2)
    tracker.record(enginePress(), at: 2.25)
    #expect(tracker.run?.mode == .flow)
    #expect(tracker.run?.counters.presses == 2)
    #expect(tracker.today.presses == 8)
    #expect(tracker.today.activeSeconds == 1.25)
    #expect(tracker.keyStats.keys["a"]?.samples == 5)
    #expect(tracker.keyStats.pairs["aa"]?.samples == 5)
  }

  @Test func selectingCurrentModeKeepsRunAndTimingSequence() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    #expect(tracker.setMode(.flow, at: 0.1) == nil)
    tracker.record(enginePress(), at: 0.25)
    #expect(tracker.run?.startedAt == 0)
    #expect(tracker.run?.counters.presses == 2)
    #expect(tracker.today.activeSeconds == 0.25)
    #expect(tracker.keyStats.keys["a"]?.samples == 1)
  }

  @Test func sprintUsesElapsedTimeAndSavesOnlyOnCompletion() throws {
    var tracker = StatsTracker(mode: .sprint)
    tracker.record(enginePress(), at: 100)
    tracker.record(enginePress(), at: 101)
    tracker.record(enginePress(), at: 121)
    #expect(tracker.run?.counters.activeSeconds == 21)
    #expect(tracker.currentCounters(at: 130)?.activeSeconds == 30)
    #expect(tracker.currentCounters(at: 130)?.wpm == 1.2)
    #expect(tracker.today.activeSeconds == 1)
    #expect(tracker.update(at: 130) == nil)
    let completedResult = tracker.endRun(at: 130, completed: true)
    let completed = try #require(completedResult)
    #expect(completed.counters.activeSeconds == 30)
    #expect(completed.shouldSave)
    #expect(completed.completed)
    #expect(completed.mode == .sprint)
    #expect(tracker.currentCounters(at: 140) == nil)
    tracker.record(enginePress(), at: 150)
    let cancelledResult = tracker.endRun(at: 155)
    let cancelled = try #require(cancelledResult)
    #expect(!cancelled.shouldSave)
    #expect(!cancelled.completed)
  }

  @Test func sprintPairsAreLocalToTheRun() throws {
    var tracker = StatsTracker(mode: .sprint)
    for (index, character) in "abab".enumerated() {
      tracker.record(enginePress(character), at: Double(index) * 0.1)
    }
    let result = tracker.endRun(at: 1, completed: true)
    let first = try #require(result)
    #expect(first.keyStats.slowestPair?.letters == "ab")
    tracker.record(enginePress("a"), at: 2)
    tracker.record(enginePress("b"), at: 2.1)
    #expect(tracker.run?.keyStats.slowestPair == nil)
    #expect(tracker.keyStats.pairs["ab"]?.samples == 3)
  }

  @Test func ignoredInputDoesNotStartRunOrAffectTiming() {
    var session = TypingSession(text: "a")
    var tracker = StatsTracker()
    tracker.record(session.handle(.character("\t")), at: 0)
    #expect(tracker.run == nil)
    tracker.record(session.handle(.character("a")), at: 1)
    tracker.record(session.handle(.character("\n")), at: 2)
    #expect(tracker.today.presses == 1)
    #expect(tracker.today.activeSeconds == 0)
  }

  @Test func idleTimeoutDoesNotEndSprint() {
    var tracker = StatsTracker(mode: .sprint)
    tracker.record(enginePress(), at: 0)
    #expect(tracker.update(at: 301) == nil)
    #expect(tracker.run != nil)
    #expect(tracker.currentCounters(at: 301)?.activeSeconds == 301)
  }

  @Test func removingCreditFromPriorRunDoesNotMakeNewRunNegative() {
    var session = TypingSession(text: "abc", mode: .forgiving)
    var tracker = StatsTracker()
    tracker.record(session.handle(.character("a")), at: 0)
    tracker.endRun(at: 0.1)
    tracker.record(session.handle(.character("b")), at: 1)
    tracker.record(session.handle(.deleteWord), at: 1.1)
    #expect(tracker.today.netCorrectChars == 0)
    #expect(tracker.run?.counters.netCorrectChars == 0)
    #expect(tracker.today.presses == 2)
  }
}
