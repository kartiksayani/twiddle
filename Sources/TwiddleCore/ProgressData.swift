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
  public let runs: [Store.Run]
  public let points: [Point]
  public let bestPoint: Point?
  public let averageY: Double
  public var oldestDate: Date? { runs.first?.startedAt }
  public var isEmpty: Bool { runs.isEmpty }

  public init(state: Store.State) {
    minutes = state.today.activeSeconds / 60
    average = state.today.counters.wpm
    best = state.today.bestWPM
    weakestKeys = state.keyStats.weakestKeys
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
}
