import Foundation
import Testing

@testable import TwiddleCore

func latencyEntry(samples: Int = 20, ms: Double = 100) throws -> KeyStats.Entry {
  try JSONDecoder().decode(
    KeyStats.Entry.self,
    from: Data("{\"samples\":\(samples),\"averageMs\":\(ms),\"errorRate\":0}".utf8))
}

struct M10StatsTests {
  @Test func rhythmNeedsTwentyGapsAndIdenticalGapsArePerfect() {
    var tracker = StatsTracker()
    for index in 0...19 { tracker.record(enginePress(), at: Double(index) / 4) }
    #expect(tracker.todayRhythm.count == 19)
    #expect(tracker.todayRhythm.value == nil)
    #expect(tracker.run?.rhythm.value == nil)
    tracker.record(enginePress(), at: 5)
    #expect(tracker.todayRhythm.value == 1)
    #expect(tracker.run?.rhythm.value == 1)
  }

  @Test func rhythmExcludesExactlyTwoSecondsAndMistakeRecovery() {
    var tracker = StatsTracker()
    tracker.record(enginePress(), at: 0)
    tracker.record(enginePress(), at: 2)
    tracker.record(enginePress(correct: false), at: 2.1)
    tracker.record(enginePress(), at: 2.2)
    #expect(tracker.todayRhythm.count == 0)
    #expect(tracker.run?.rhythm.count == 0)
    tracker.record(enginePress(), at: 2.5)
    #expect(tracker.todayRhythm.count == 1)
    #expect(tracker.run?.rhythm.count == 1)
  }

  @Test func rhythmBackspaceDoesNotAddOrBreakGaps() {
    var session = TypingSession(text: "aa", mode: .forgiving)
    var tracker = StatsTracker()
    tracker.record(session.handle(.character("a")), at: 0)
    tracker.record(session.handle(.backspace), at: 0.1)
    #expect(tracker.todayRhythm.count == 0)
    tracker.record(session.handle(.character("a")), at: 0.25)
    #expect(tracker.todayRhythm.count == 1)
    #expect(tracker.todayRhythm.mean == 0.25)
    #expect(tracker.run?.rhythm == tracker.todayRhythm)
  }

  @Test func resetTodayClearsRhythmAndItsSequenceButKeepsRunRhythm() {
    var tracker = StatsTracker()
    for index in 0...20 { tracker.record(enginePress(), at: Double(index) / 4) }
    let rhythm = tracker.run?.rhythm
    tracker.resetToday()
    #expect(tracker.todayRhythm == Rhythm())
    #expect(tracker.run?.rhythm == rhythm)
    tracker.record(enginePress(), at: 5.25)
    #expect(tracker.todayRhythm.count == 0)
    #expect(tracker.run?.rhythm.count == 21)
  }

  @Test func rhythmClampsWhenStandardDeviationExceedsMean() {
    var rhythm = Rhythm()
    for _ in 0..<19 { rhythm.record(0.01) }
    rhythm.record(1.9)
    #expect(rhythm.value == 0)
    var zeros = Rhythm()
    for _ in 0..<20 { zeros.record(0) }
    #expect(zeros.value == 1)
  }

  @Test func rhythmUsesWelfordPopulationVarianceAndIncludesWhitespaceGaps() throws {
    var tracker = StatsTracker()
    for index in 0...20 {
      tracker.record(enginePress(index.isMultiple(of: 2) ? "a" : " "), at: Double(index) / 4)
    }
    #expect(tracker.todayRhythm.count == 20)
    #expect(tracker.todayRhythm.value == 1)
    var rhythm = Rhythm()
    for _ in 0..<10 {
      rhythm.record(0.1)
      rhythm.record(0.3)
    }
    #expect(abs(rhythm.mean - 0.2) < 0.000001)
    #expect(abs(rhythm.m2 - 0.2) < 0.000001)
    #expect(abs(try #require(rhythm.value) - 0.5) < 0.000001)
  }

  @Test func runEndRestartsRhythmWhileTodayAccumulates() throws {
    var tracker = StatsTracker()
    for index in 0...20 { tracker.record(enginePress(), at: Double(index) / 4) }
    let result = tracker.endRun(at: 5)
    let ended = try #require(result)
    #expect(ended.rhythm.value == 1)
    tracker.record(enginePress(), at: 5.25)
    #expect(tracker.run?.rhythm.count == 0)
    #expect(tracker.todayRhythm.count == 20)
  }

  @Test func slowestPairsNeedTenSamplesAndKeepSprintThreshold() throws {
    let stats = KeyStats(pairs: [
      "ab": try latencyEntry(samples: 9, ms: 400),
      "cd": try latencyEntry(samples: 10, ms: 300),
    ])
    #expect(stats.slowestPairs.map(\.letters) == ["cd"])
    #expect(stats.slowestPair?.letters == "ab")
  }

  @Test func slowestPairsRankByAverageThenAlphabeticallyAndLimitToFive() throws {
    var pairs: [String: KeyStats.Entry] = [:]
    for pair in ["zz", "ee", "dd", "cc", "bb", "aa"] {
      pairs[pair] = try latencyEntry(ms: pair == "zz" ? 200 : 100)
    }
    let stats = KeyStats(pairs: pairs)
    #expect(stats.slowestPairs.map(\.letters) == ["zz", "aa", "bb", "cc", "dd"])
  }

  @Test(arguments: [19, 20], [19, 20])
  func stallsNeedTwentySamplesOnBothSides(letters: Int, symbols: Int) throws {
    var state = Store.State(date: "2026-10-31")
    state.keys = [
      "a": try latencyEntry(samples: letters), "!": try latencyEntry(samples: symbols, ms: 240),
    ]
    let data = ProgressData(state: state)
    #expect(data.symbolStallRatio == (letters == 20 && symbols == 20 ? 2.4 : nil))
    #expect(
      data.keyLatencyCaption
        == (letters == 20 && symbols == 20
          ? "symbols 2.4× slower than letters" : "average ms per key"))
  }

  @Test(arguments: [50.0, 100])
  func equalOrFasterSymbolsKeepCaption(milliseconds: Double) throws {
    var state = Store.State(date: "2026-10-31")
    state.keys = ["a": try latencyEntry(), "!": try latencyEntry(ms: milliseconds)]
    #expect(ProgressData(state: state).symbolStallRatio == nil)
    #expect(ProgressData(state: state).keyLatencyCaption == "average ms per key")
  }

  @Test func stallsUseSampleWeightedAveragesAcrossEveryRecordedKey() throws {
    var state = Store.State(date: "2026-10-31")
    state.keys = [
      "a": try latencyEntry(samples: 10, ms: 100),
      "z": try latencyEntry(samples: 30, ms: 300),
      "!": try latencyEntry(samples: 10, ms: 500),
      "1": try latencyEntry(samples: 30, ms: 700),
    ]
    #expect(ProgressData(state: state).symbolStallRatio == 2.6)
  }

  @Test func progressReadsRhythmAndSparsePairs() throws {
    var state = Store.State(date: "2026-10-31")
    var rhythm = Rhythm()
    for _ in 0..<20 { rhythm.record(0.25) }
    state.today.rhythm = rhythm
    state.pairs = ["ab": try latencyEntry(samples: 10)]
    let data = ProgressData(state: state)
    #expect(data.rhythm == 1)
    #expect(data.slowestPairs.map(\.letters) == ["ab"])
    #expect(data.weakestKeys.isEmpty)
  }

  @Test func weakWordRankingRewardsEachPairOccurrenceIncludingOverlaps() {
    #expect(
      ContentProvider.ranked(["q", "aaa", "aa", "qqq"], for: ["q"], pairs: ["aa"])
        == ["aaa", "qqq", "aa", "q"])
    #expect(ContentProvider.ranked(["ab", "cd"], for: [], pairs: []) == ["ab", "cd"])
  }

  @Test func pairDataDoesNotChangeWeakKeysFallback() throws {
    var random = FixedRandom()
    let stats = KeyStats(pairs: ["aa": try latencyEntry()])
    #expect(ContentProvider().content(for: .weakKeys, keyStats: stats, using: &random).fellBack)
  }
}
