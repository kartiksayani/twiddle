import Foundation

public struct Rhythm: Codable, Equatable, Sendable {
  public private(set) var count = 0
  public private(set) var mean = 0.0
  public private(set) var m2 = 0.0

  public init() {}

  public var value: Double? {
    guard count >= 20 else { return nil }
    guard mean > 0 else { return 1 }
    return min(1, max(0, 1 - sqrt(max(0, m2) / Double(count)) / mean))
  }

  public mutating func record(_ gap: TimeInterval) {
    count += 1
    let delta = gap - mean
    mean += delta / Double(count)
    m2 += delta * (gap - mean)
  }
}
