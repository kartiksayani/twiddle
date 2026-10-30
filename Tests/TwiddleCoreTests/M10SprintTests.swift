import Foundation
import Testing
import TwiddleCore

// State / event                         Outcome
// Flow, ready, locked, result / clock    No ghost
// Running without best / clock          No ghost
// Running / clock                       This length's best, within real caret's lines
// Running / hide or quit                Cancel; no ghost or best update
// Running / completion                  Save best; ghost clears; ties are not new bests
// Missing bests / launch                 Seed nearest lengths once from sprint runs
// Saved bests / relaunch                 Keep bests, even after history expires
@MainActor
struct M10SprintTests {
  private func seed(_ f: PracticeFixture, bests: [Int: Double]? = nil, runs: [Store.Run] = [])
    throws
  {
    var state = Store.State(date: f.store.today)
    state.bestSprintWPM = bests
    state.runs = runs
    try f.store.save(state)
  }

  private func start(_ f: PracticeFixture) {
    f.model.summon()
    f.model.handle(.sprint)
    f.model.handle(.character(f.model.session.expected!))
  }

  private func run(seconds: Double, wpm: Double, mode: StatsTracker.Mode = .sprint) -> Store.Run {
    .init(
      mode: mode, source: .words, startedAt: Date(timeIntervalSince1970: 0),
      activeSeconds: seconds, wpm: wpm, accuracy: 1, chars: 100)
  }

  @Test func noBestGivesNoGhost() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.time = 1
    f.model.tick()
    #expect(f.model.ghostOffset == nil)
  }

  @Test func flowAndReadyGiveNoGhostEvenWithBest() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: [30: 60])
    f.model.summon()
    f.type(1)
    #expect(f.model.ghostOffset == nil)
    f.model.handle(.sprint)
    #expect(f.model.ghostOffset == nil)
  }

  @Test func ghostStartsAtZeroAndUsesEachLengthsOwnBest() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: [15: 24, 30: 48, 60: 96])
    f.model.summon()
    f.model.handle(.sprint)
    for (length, expected) in [(30, 8.0), (60, 16.0), (15, 4.0)] {
      #expect(f.model.sprintLength == length)
      f.model.handle(.character(f.model.session.expected!))
      #expect(f.model.ghostOffset == 0)
      f.time += 2
      f.model.tick()
      #expect(f.model.ghostOffset == expected)
      f.model.handle(.sprint)
      f.model.handle(.sprint)
    }
  }

  @Test func ghostHidesAtEndOfVisibleLinesAndWhenBehindRealCaret() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: [30: 120])
    start(f)
    let end = Double(f.model.lines[1].upperBound)
    f.time = (end - 0.25) / 10
    f.model.tick()
    #expect(f.model.ghostOffset != nil)
    f.time = end / 10
    f.model.tick()
    #expect(f.model.ghostOffset == nil)
    f.type(120)
    #expect(f.model.lines.first!.upperBound <= f.model.session.caret)
    // Move the real caret ahead of a slow ghost on a fresh run.
    f.model.handle(.sprint)
    for _ in 0..<120 { f.model.handle(.character(f.model.session.expected!)) }
    f.model.tick()
    #expect(f.model.ghostOffset == nil)
  }

  @Test(arguments: [false, true])
  func hideOrQuitCancelsGhostAndDoesNotSetBest(quitting: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: [30: 60])
    start(f)
    #expect(f.model.ghostOffset == 0)
    if quitting { f.model.quit() } else { f.model.hide() }
    #expect(f.model.ghostOffset == nil)
    #expect(f.model.state.bestSprintWPM == [30: 60])
    #expect(f.model.state.runs.isEmpty)
    f.model.summon()
    #expect(f.model.ghostOffset == nil)
  }

  @Test func lockAndResultClearGhostAndExposeRunRhythm() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: [30: 60])
    f.model.summon()
    f.model.handle(.sprint)
    f.type(50)
    let rhythm = f.model.stats.run?.rhythm
    f.time = 30
    f.model.tick()
    #expect(f.model.sprintState == .locked)
    #expect(f.model.ghostOffset == nil)
    f.time = 30.6
    f.model.tick()
    #expect(f.model.sprintState == .result)
    #expect(f.model.ghostOffset == nil)
    #expect(f.model.result?.rhythm == rhythm)
    #expect(f.model.result?.rhythm.value != nil)
  }

  @Test func seedsOnlySprintRunsWithMaximumPerNearestLength() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(
      f,
      runs: [
        run(seconds: 15, wpm: 20), run(seconds: 14, wpm: 50),
        run(seconds: 28, wpm: 70), run(seconds: 55, wpm: 80),
        run(seconds: 60, wpm: 200, mode: .flow),
      ])
    #expect(f.model.state.bestSprintWPM == [15: 50, 30: 70, 60: 80])
    f.model.quit()
    #expect(f.store.load().state.bestSprintWPM == [15: 50, 30: 70, 60: 80])
  }

  @Test func existingEmptyBestsAreNotSeededAgain() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: [:], runs: [run(seconds: 30, wpm: 90)])
    #expect(f.model.state.bestSprintWPM == [:])
  }

  @Test(arguments: [nil, 20.0, 19.0, 21.0])
  func onlyBeatingAnExistingBestShowsNewBest(previous: Double?) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f, bests: previous.map { [30: $0] })
    f.model.summon()
    f.model.handle(.sprint)
    f.type(50)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    #expect(f.model.result?.counters.wpm == 20)
    #expect(f.model.result?.isNewBest == (previous == 19))
    #expect(f.model.state.bestSprintWPM?[30] == max(previous ?? 0, 20))
  }

  @Test func bestAndTodayRhythmPersistAcrossRelaunchBeyondHistory() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    start(f)
    f.type(50)
    f.time = 30
    f.model.tick()
    let best = f.model.state.bestSprintWPM
    let rhythm = f.model.stats.todayRhythm
    var saved = f.store.load().state
    saved.runs = []
    try f.store.save(saved)
    let relaunched = PracticeModel(store: f.store, random: FixedRandom(), now: { f.time })
    #expect(relaunched.state.bestSprintWPM == best)
    #expect(relaunched.stats.todayRhythm == rhythm)
    #expect(relaunched.progress.rhythm == rhythm.value)
    relaunched.summon()
    relaunched.handle(.sprint)
    relaunched.handle(.character(relaunched.session.expected!))
    #expect(relaunched.ghostOffset == 0)
    #expect(relaunched.stats.todayRhythm == rhythm)
    #expect(relaunched.stats.run?.rhythm.count == 0)
    f.date = f.date.addingTimeInterval(86400)
    relaunched.refreshToday()
    #expect(relaunched.stats.todayRhythm == Rhythm())
    #expect(relaunched.progress.rhythm == nil)
    #expect(relaunched.state.bestSprintWPM == best)
  }
}
