import Testing
import TwiddleCore

struct KeyStatsTests {
  @Test func firstCorrectPressHasNoLatency() {
    var stats = KeyStats()
    stats.record(enginePress(), at: 5)
    #expect(stats.keys["a"]?.samples == 0)
    #expect(stats.keys["a"]?.averageMs == 0)
    #expect(stats.keys["a"]?.errorRate == 0)
    #expect(stats.pairs.isEmpty)
  }

  @Test(arguments: [2.0, 2.001, 10.0])
  func latencyAtTwoSecondsOrMoreIsSkipped(gap: Double) throws {
    var stats = KeyStats()
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress("b"), at: gap)
    #expect(stats.keys["b"]?.samples == 0)
    #expect(stats.pairs.isEmpty)
    stats.record(enginePress("c"), at: gap + 0.25)
    let entry = try #require(stats.keys["c"])
    #expect(entry.samples == 1)
    #expect(abs(entry.averageMs - 250) < 0.0001)
    #expect(stats.pairs["bc"]?.samples == 1)
  }

  @Test func latencyJustUnderTwoSecondsIsIncluded() throws {
    var stats = KeyStats()
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress("b"), at: 1.999)
    let entry = try #require(stats.keys["b"])
    #expect(entry.samples == 1)
    #expect(abs(entry.averageMs - 1999) < 0.0001)
  }

  @Test func mistakeBreaksSequenceIncludingRecoveryPress() {
    var stats = KeyStats()
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress("b", correct: false), at: 0.1)
    stats.record(enginePress("b"), at: 0.2)
    #expect(stats.keys["b"]?.samples == 0)
    #expect(stats.keys["b"]?.errorRate == 0.9)
    #expect(stats.pairs.isEmpty)
    stats.record(enginePress("c"), at: 0.4)
    #expect(stats.keys["c"]?.samples == 1)
    #expect(stats.pairs["bc"]?.samples == 1)
  }

  @Test(arguments: Array("1-!"))
  func symbolStaysAsTypedAndPreventsPairButNotKeyLatency(character: Character) {
    var stats = KeyStats()
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress(character), at: 0.1)
    stats.record(enginePress("b"), at: 0.2)
    #expect(stats.pairs.isEmpty)
    #expect(stats.keys[character]?.samples == 1)
    #expect(stats.keys["b"]?.samples == 1)
  }

  @Test(arguments: Array(" \n"))
  func correctWhitespaceIsUnrecordedButContinuesLatencySequence(character: Character) throws {
    var stats = KeyStats()
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress(character), at: 0.25)
    stats.record(enginePress("b"), at: 0.75)
    #expect(stats.keys[character] == nil)
    #expect(stats.pairs.isEmpty)
    let following = try #require(stats.keys["b"])
    #expect(following.samples == 1)
    #expect(following.averageMs == 500)
  }

  @Test(arguments: Array(" \n"))
  func wrongWhitespaceIsUnrecordedButBreaksLatencySequence(character: Character) {
    var stats = KeyStats()
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress(character, correct: false), at: 0.25)
    stats.record(enginePress("b"), at: 0.75)
    #expect(stats.keys[character] == nil)
    #expect(stats.keys["b"]?.samples == 0)
    #expect(stats.pairs.isEmpty)
  }

  @Test func uppercaseLettersAreLowercasedInKeysAndPairs() {
    var stats = KeyStats()
    for (index, character) in "AbAB".enumerated() {
      stats.record(enginePress(character), at: Double(index) * 0.25)
    }
    #expect(stats.pairs["ab"]?.samples == 2)
    #expect(stats.pairs["ba"]?.samples == 1)
    #expect(stats.pairs["AB"] == nil)
    #expect(stats.slowestPair?.letters == "ab")
    #expect(stats.keys["B"] == nil)
    #expect(stats.keys["A"] == nil)
    #expect(stats.keys["b"]?.samples == 2)
    #expect(stats.keys["b"]?.averageMs == 250)
  }

  @Test func letterCaseSharesLatencyAndErrorHistory() throws {
    var stats = KeyStats()
    stats.record(enginePress("t"), at: 0)
    stats.record(enginePress("T"), at: 0.25)
    stats.record(enginePress("T", correct: false), at: 0.5)
    let entry = try #require(stats.keys["t"])
    #expect(stats.keys.count == 1)
    #expect(entry.samples == 1)
    #expect(entry.averageMs == 250)
    #expect(entry.errorRate == 0.1)
    stats.record(enginePress("a"), at: 0.75)
    #expect(stats.keys["a"]?.samples == 0)
  }

  @Test func weakestKeysNeverContainWhitespaceOrUppercaseLetters() {
    var stats = KeyStats()
    for (index, key) in " \nTt!".enumerated() {
      stats.breakSequence()
      for sample in 0...20 {
        stats.record(enginePress(key), at: Double(index * 10) + Double(sample) * 0.25)
      }
    }
    #expect(stats.keys[" "] == nil)
    #expect(stats.keys["\n"] == nil)
    #expect(stats.keys["T"] == nil)
    #expect(stats.keys["t"]?.samples == 40)
    #expect(stats.weakestKeys.map(\.key) == ["!", "t"])
    #expect(stats.weakestKeys.allSatisfy { !$0.key.isWhitespace && !$0.key.isUppercase })
  }

  @Test func latencyUsesEWMAWithAlphaPointOne() throws {
    var stats = KeyStats()
    stats.record(enginePress(), at: 0)
    stats.record(enginePress(), at: 0.1)
    stats.record(enginePress(), at: 0.4)
    let key = try #require(stats.keys["a"])
    let pair = try #require(stats.pairs["aa"])
    #expect(key.samples == 2)
    #expect(abs(key.averageMs - 120) < 0.0001)
    #expect(abs(pair.averageMs - 120) < 0.0001)
  }

  @Test func errorRateUsesAllAttemptsAtExpectedKey() throws {
    var stats = KeyStats()
    stats.record(enginePress(), at: 0)
    stats.record(enginePress(correct: false), at: 0.1)
    stats.record(enginePress(correct: false), at: 0.2)
    stats.record(enginePress(), at: 0.3)
    let entry = try #require(stats.keys["a"])
    #expect(entry.samples == 0)
    #expect(abs(entry.errorRate - 0.171) < 0.0001)
    #expect(stats.keys["!"] == nil)
  }

  @Test func fewerThanTwentyTimingSamplesAreExcluded() {
    var stats = KeyStats()
    for index in 0..<20 { stats.record(enginePress(), at: Double(index) * 0.1) }
    #expect(stats.keys["a"]?.samples == 19)
    #expect(stats.weakestKeys.isEmpty)
    stats.record(enginePress(), at: 2)
    #expect(stats.keys["a"]?.samples == 20)
    #expect(stats.weakestKeys.map(\.key) == ["a"])
  }

  @Test func weakestKeysRankByScoreAndReturnOnlyFive() throws {
    var stats = KeyStats()
    for (index, key) in "abcdefg".enumerated() {
      stats.breakSequence()
      for sample in 0...20 {
        stats.record(enginePress(key), at: Double(index * 100) + Double(sample) * 0.1)
      }
    }
    stats.record(enginePress("g", correct: false), at: 603)
    stats.record(enginePress("g", correct: false), at: 603.1)
    let weakest = stats.weakestKeys
    #expect(weakest.count == 5)
    #expect(weakest.first?.key == "g")
    let entry = try #require(stats.keys["g"])
    #expect(abs(entry.score - 138) < 0.0001)
    #expect(zip(weakest, weakest.dropFirst()).allSatisfy { $0.stats.score >= $1.stats.score })
  }

  @Test func weakestKeyTiesHaveStableAlphabeticOrder() {
    var stats = KeyStats()
    for key: Character in ["b", "a"] {
      stats.breakSequence()
      for sample in 0...20 { stats.record(enginePress(key), at: Double(sample) * 0.25) }
    }
    #expect(stats.weakestKeys.map(\.key) == ["a", "b"])
  }

  @Test func slowestPairRequiresTwoSamples() {
    var stats = KeyStats()
    #expect(stats.slowestPair == nil)
    stats.record(enginePress("a"), at: 0)
    stats.record(enginePress("b"), at: 0.25)
    #expect(stats.slowestPair == nil)
    stats.record(enginePress("a"), at: 0.5)
    stats.record(enginePress("b"), at: 0.75)
    #expect(stats.slowestPair?.letters == "ab")
    #expect(stats.slowestPair?.stats.samples == 2)
  }

  @Test func slowestPairUsesAverageAndStableTieOrder() {
    var stats = KeyStats()
    for pair in ["cd", "ab", "ef"] {
      for sample in 0..<2 {
        stats.breakSequence()
        let time = Double(sample) * 2
        stats.record(enginePress(pair.first!), at: time)
        stats.record(enginePress(pair.last!), at: time + (pair == "ef" ? 0.25 : 0.5))
      }
    }
    #expect(stats.slowestPair?.letters == "ab")
    #expect(stats.slowestPair?.stats.averageMs == 500)
  }

  @Test func deletionIsNotAPressAndDoesNotBreakCorrectPressSequence() {
    var session = TypingSession(text: "ab", mode: .forgiving)
    var stats = KeyStats()
    stats.record(session.handle(.character("a")), at: 0)
    stats.record(session.handle(.backspace), at: 0.1)
    stats.record(session.handle(.character("a")), at: 0.25)
    #expect(stats.keys["a"]?.samples == 1)
    #expect(stats.pairs["aa"]?.samples == 1)
  }
}
