import Foundation

public struct KeyStats {
  public struct Entry: Equatable, Codable, Sendable {
    /// Samples count eligible latencies; error EWMA includes every attempt at this key.
    public fileprivate(set) var samples = 0
    public fileprivate(set) var averageMs = 0.0
    public fileprivate(set) var errorRate = 0.0
    private var hasAttempts = false

    private enum CodingKeys: CodingKey { case samples, averageMs, errorRate }

    public init() {}

    public static func == (lhs: Entry, rhs: Entry) -> Bool {
      lhs.samples == rhs.samples && lhs.averageMs == rhs.averageMs && lhs.errorRate == rhs.errorRate
    }

    public init(from decoder: any Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      samples = try values.decode(Int.self, forKey: .samples)
      averageMs = try values.decode(Double.self, forKey: .averageMs)
      errorRate = try values.decode(Double.self, forKey: .errorRate)
      guard samples >= 0, averageMs >= 0, averageMs.isFinite,
        errorRate.isFinite, (0...1).contains(errorRate)
      else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: decoder.codingPath, debugDescription: "Invalid key statistics"))
      }
      // A saved entry exists only after an attempt, even with no latency samples.
      hasAttempts = true
    }

    public var score: Double { averageMs * (1 + 2 * errorRate) }

    fileprivate mutating func recordError(_ wrong: Bool) {
      let value = wrong ? 1.0 : 0.0
      errorRate = hasAttempts ? errorRate + 0.1 * (value - errorRate) : value
      hasAttempts = true
    }

    fileprivate mutating func recordLatency(_ milliseconds: Double) {
      averageMs = samples == 0 ? milliseconds : averageMs + 0.1 * (milliseconds - averageMs)
      samples += 1
      hasAttempts = true
    }
  }

  public struct RankedKey: Equatable {
    public let key: Character
    public let stats: Entry
  }

  public struct Pair: Equatable {
    public let letters: String
    public let stats: Entry
  }

  public private(set) var keys: [Character: Entry] = [:]
  public private(set) var pairs: [String: Entry] = [:]
  private var previousCorrect: (key: Character, time: TimeInterval)?

  public init(keys: [Character: Entry] = [:], pairs: [String: Entry] = [:]) {
    self.keys = keys
    self.pairs = pairs
  }

  public var weakestKeys: [RankedKey] {
    let eligible = keys.filter { $0.value.samples >= 20 }
      .map { RankedKey(key: $0.key, stats: $0.value) }
    let ranked = eligible.sorted { left, right in
      if left.stats.score == right.stats.score {
        return String(left.key) < String(right.key)
      }
      return left.stats.score > right.stats.score
    }
    return Array(ranked.prefix(5))
  }

  public var slowestPair: Pair? {
    let eligible = pairs.filter { $0.value.samples >= 2 }
      .map { Pair(letters: $0.key, stats: $0.value) }
    return eligible.sorted { left, right in
      if left.stats.averageMs == right.stats.averageMs {
        return left.letters < right.letters
      }
      return left.stats.averageMs > right.stats.averageMs
    }.first
  }

  public mutating func breakSequence() {
    previousCorrect = nil
  }

  /// Times are supplied by the caller in monotonically increasing seconds.
  public mutating func record(_ change: TypingSession.Change, at time: TimeInterval) {
    guard let expected = change.expected, change.isPress else { return }
    let key = Character(String(expected).lowercased())
    let recordsKey = key != " " && key != "\n"
    if recordsKey { keys[key, default: Entry()].recordError(!change.isCorrect) }
    guard change.isCorrect else {
      breakSequence()
      return
    }
    if let previousCorrect {
      let gap = time - previousCorrect.time
      if gap >= 0 && gap < 2 {
        if recordsKey { keys[key, default: Entry()].recordLatency(gap * 1000) }
        let letters = String([previousCorrect.key, key]).lowercased()
        if letters.utf8.count == 2 && letters.utf8.allSatisfy({ $0 >= 97 && $0 <= 122 }) {
          pairs[letters, default: Entry()].recordLatency(gap * 1000)
        }
      }
    }
    previousCorrect = (key, time)
  }
}
