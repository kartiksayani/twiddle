import Foundation
import Testing
import TwiddleCore

struct RestoreTests {
  @Test func keyRestoreThenNextPressKeepsHistoryButStartsSequence() throws {
    var stats = KeyStats()
    for index in 0..<22 { stats.record(enginePress(), at: Double(index) * 0.25) }
    let keys = try JSONDecoder().decode(
      [String: KeyStats.Entry].self,
      from: JSONEncoder().encode(
        Dictionary(uniqueKeysWithValues: stats.keys.map { (String($0.key), $0.value) })))
    var restored = KeyStats(keys: ["a": try #require(keys["a"])], pairs: stats.pairs)
    restored.record(enginePress(), at: 5.3)
    #expect(restored.keys["a"]?.samples == 21)
    restored.record(enginePress(), at: 5.8)
    #expect(restored.keys["a"]?.samples == 22)
    #expect(restored.keys["a"]?.averageMs == 275)
    #expect(restored.pairs["aa"]?.samples == 22)
  }

  @Test func errorOnlyKeyRestoresWithoutLosingFirstErrorOnNextPress() throws {
    var stats = KeyStats()
    stats.record(enginePress(correct: false), at: 0)
    let entry = try JSONDecoder().decode(
      KeyStats.Entry.self,
      from: JSONEncoder().encode(try #require(stats.keys["a"])))
    var restored = KeyStats(keys: ["a": entry])
    #expect(entry.samples == 0)
    #expect(entry.averageMs == 0)
    #expect(entry.errorRate == 1)
    restored.record(enginePress(), at: 0.1)
    #expect(restored.keys["a"]?.errorRate == 0.9)
    #expect(restored.keys["a"]?.samples == 0)
  }

  @Test func trackerRestoreThenNextPressStartsFreshRunAndTiming() throws {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    tracker.record(enginePress(), at: 0.25)
    let saved = try JSONEncoder().encode(tracker.today)
    let today = try JSONDecoder().decode(StatsTracker.Counters.self, from: saved)
    var restored = StatsTracker(today: today, keyStats: tracker.keyStats)
    #expect(restored.run == nil)
    #expect(!restored.isPaused(at: 100))
    restored.record(enginePress(), at: 0.5)
    #expect(restored.today.presses == 3)
    #expect(restored.today.activeSeconds == 0.25)
    #expect(restored.keyStats.keys["a"]?.samples == 1)
    #expect(restored.run?.counters.netCorrectChars == 1)
    restored.record(enginePress(), at: 0.75)
    #expect(restored.today.activeSeconds == 0.5)
    #expect(restored.keyStats.keys["a"]?.samples == 2)
  }

  @Test func dayResetKeepsKeyStatsAndCurrentRun() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    tracker.record(enginePress(), at: 0.25)
    let keys = tracker.keyStats.keys
    let pairs = tracker.keyStats.pairs
    let run = tracker.run?.counters
    tracker.resetToday()
    #expect(tracker.today == StatsTracker.Counters())
    #expect(tracker.keyStats.keys == keys)
    #expect(tracker.keyStats.pairs == pairs)
    #expect(tracker.run?.counters == run)
    tracker.record(enginePress(), at: 0.5)
    #expect(tracker.today.presses == 1)
    #expect(tracker.today.activeSeconds == 0.25)
    #expect(tracker.keyStats.keys["a"]?.samples == 1)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func restoreRebuildsCreditForCorrections(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "abc", caret: 2, mistakes: [0], mode: mode)
    #expect(session.caret == 2)
    #expect(session.mistakes == [0])
    #expect(session.pending == nil)
    #expect(session.netCorrectChars == (mode == .strict ? 2 : 1))
    session.setMode(.forgiving)
    #expect(session.handle(.backspace).netCorrectChars == -1)
    #expect(session.handle(.backspace).netCorrectChars == (mode == .strict ? -1 : 0))
  }

  @Test func restoredIndentationIsNotCredited() {
    var session = TypingSession(text: "  a\n  b", caret: 7, mistakes: [], mode: .forgiving)
    #expect(session.netCorrectChars == 3)
    #expect(session.handle(.backspace).netCorrectChars == -1)
    #expect(session.handle(.backspace).netCorrectChars == 0)
    #expect(session.handle(.backspace).netCorrectChars == 0)
    #expect(session.handle(.backspace).netCorrectChars == -1)
  }

  @Test func resumeClearsPendingAndKeepsOnlyEarlierMarksAndCredit() {
    var session = TypingSession(text: "a cat")
    for key in "xay cax" { session.handle(.character(key)) }
    #expect(session.pending != nil)
    session.resumeAtWordStart()
    #expect(session.caret == 2)
    #expect(session.pending == nil)
    #expect(session.mistakes == [0, 1])
    #expect(session.netCorrectChars == 2)
  }

  @Test func hideWordStartResumeThenCorrectionKeepsEarlierCredit() {
    var session = TypingSession(text: "a cat", mode: .forgiving)
    var tracker = StatsTracker()
    for (index, key) in "x ca".enumerated() {
      tracker.record(session.handle(.character(key)), at: Double(index) * 0.25)
    }
    tracker.endRun(at: 1)
    session.resumeAtWordStart()
    #expect(session.caret == 2)
    #expect(session.mistakes == [0])
    #expect(session.netCorrectChars == 1)
    tracker.record(session.handle(.backspace), at: 2)
    #expect(session.caret == 1)
    #expect(session.netCorrectChars == 0)
    #expect(tracker.today.netCorrectChars == 2)
    tracker.record(session.handle(.character(" ")), at: 2.1)
    #expect(tracker.today.netCorrectChars == 3)
    #expect(tracker.today.presses == 5)
  }

  @Test func resumeAtWordBoundaryOrEmptyTextDoesNotDeletePreviousWord() {
    var session = TypingSession(text: "one two", caret: 4, mistakes: [0, 4])
    session.resumeAtWordStart()
    #expect(session.caret == 4)
    #expect(session.mistakes == [0])
    var empty = TypingSession(text: "")
    empty.resumeAtWordStart()
    #expect(empty.caret == 0)
    var end = TypingSession(text: "one", caret: 3, mistakes: [])
    end.resumeAtWordStart()
    #expect(end.caret == 0)
  }

  @Test func invalidRestoreOffsetsAreClamped() {
    let session = TypingSession(text: "a", caret: 4, mistakes: [-1, 0, 1])
    #expect(session.caret == 1)
    #expect(session.mistakes == [0])
    #expect(TypingSession(text: "a", caret: -1, mistakes: []).caret == 0)
  }
}
