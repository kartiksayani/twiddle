import Foundation

public struct ProgressData {
  public struct Point: Equatable, Sendable {
    public let x: Double
    public let y: Double
  }

  public let minutes: Double
  public let average: Double
  public let best: Double
  public let weakestKeys: [KeyStats.RankedKey]
  public let slowestPairs: [KeyStats.Pair]
  public let rhythm: Double?
  public let symbolStallRatio: Double?
  public var keyLatencyCaption: String {
    guard let symbolStallRatio else { return "average ms per key" }
    return
      "symbols \(symbolStallRatio.formatted(.number.precision(.fractionLength(1))))× slower than letters"
  }
  public let runs: [Store.Run]
  public let points: [Point]
  public let bestPoint: Point?
  public let averageY: Double
  public var oldestDate: Date? { runs.first?.startedAt }
  public var isEmpty: Bool { runs.isEmpty }
  /// The chart spans days, so its best differs from today's `best`.
  public var chartBest: Double { runs.map(\.wpm).max() ?? 0 }

  public init(state: Store.State) {
    minutes = state.today.activeSeconds / 60
    average = state.today.counters.wpm
    best = state.today.bestWPM
    weakestKeys = state.keyStats.weakestKeys
    slowestPairs = state.keyStats.slowestPairs
    rhythm = state.today.rhythm?.value
    symbolStallRatio = Self.stallRatio(keys: state.keys)
    runs = Array(state.runs.sorted { $0.startedAt > $1.startedAt }.prefix(20).reversed())
    let values = runs.map(\.wpm)
    let low = min(values.min() ?? 0, average) - 5
    let high = max(values.max() ?? 0, average) + 3
    func y(_ value: Double) -> Double { 1 - (value - low) / (high - low) }
    let points = values.enumerated().map { index, value in
      Point(x: values.count == 1 ? 0.5 : Double(index) / Double(values.count - 1), y: y(value))
    }
    self.points = points
    bestPoint = values.firstIndex(of: values.max() ?? 0).map { points[$0] }
    averageY = y(average)
  }

  private static func stallRatio(keys: [String: KeyStats.Entry]) -> Double? {
    var letters = (samples: 0, total: 0.0)
    var symbols = (samples: 0, total: 0.0)
    for (key, entry) in keys {
      if key.utf8.count == 1, let byte = key.utf8.first, (97...122).contains(byte) {
        letters.samples += entry.samples
        letters.total += entry.averageMs * Double(entry.samples)
      } else {
        symbols.samples += entry.samples
        symbols.total += entry.averageMs * Double(entry.samples)
      }
    }
    guard letters.samples >= 20, symbols.samples >= 20, letters.total > 0 else { return nil }
    let ratio =
      (symbols.total / Double(symbols.samples)) / (letters.total / Double(letters.samples))
    return ratio > 1 ? ratio : nil
  }
}
