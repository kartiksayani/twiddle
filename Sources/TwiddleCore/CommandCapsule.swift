import Foundation

public struct CommandCapsule {
  public enum Event {
    case commandDown, commandUp, chord, tick, dismiss
  }

  public private(set) var isVisible = false
  private var heldSince: TimeInterval?
  private var consumed = false

  public init() {}

  public mutating func handle(_ event: Event, at time: TimeInterval) {
    switch event {
    case .commandDown:
      if heldSince == nil && !consumed { heldSince = time }
    case .commandUp, .dismiss:
      heldSince = nil
      consumed = false
      isVisible = false
    case .chord:
      heldSince = nil
      consumed = true
    case .tick:
      if let heldSince, time - heldSince >= 0.3 { isVisible = true }
    }
  }
}
