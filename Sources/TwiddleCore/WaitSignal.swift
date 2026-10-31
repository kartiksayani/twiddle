import Foundation

public enum WaitSignal: Equatable, Sendable {
  case done

  public init?(url: URL) {
    guard url.absoluteString == "twiddle://done" else { return nil }
    self = .done
  }
}
