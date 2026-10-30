public struct PanelPresence {
  public enum State {
    case hidden
    case visible
  }

  public enum Event: Sendable {
    case hotkey
    case escape
    case resignKey
    case outsideMouseDown
    case insideMouseDown
  }

  public enum Effect {
    case show
    case hide
  }

  public private(set) var state: State = .hidden

  public init() {}

  public mutating func handle(_ event: Event) -> Effect? {
    switch (state, event) {
    case (.hidden, .hotkey):
      state = .visible
      return .show
    case (.visible, .hotkey), (.visible, .escape), (.visible, .resignKey),
      (.visible, .outsideMouseDown):
      state = .hidden
      return .hide
    default:
      return nil
    }
  }
}
