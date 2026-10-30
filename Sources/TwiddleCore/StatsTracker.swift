import Foundation

public struct StatsTracker {
  public struct Counters: Equatable, Codable, Sendable {
    public fileprivate(set) var netCorrectChars = 0
    public fileprivate(set) var presses = 0
    public fileprivate(set) var correctPresses = 0
    public fileprivate(set) var activeSeconds: TimeInterval = 0

    public init(
      netCorrectChars: Int = 0, presses: Int = 0, correctPresses: Int = 0,
      activeSeconds: TimeInterval = 0
    ) {
      self.netCorrectChars = netCorrectChars
      self.presses = presses
      self.correctPresses = correctPresses
      self.activeSeconds = activeSeconds
    }

    public var wpm: Double {
      activeSeconds > 0 ? Double(netCorrectChars) * 12 / activeSeconds : 0
    }

    public var accuracy: Double {
      presses > 0 ? Double(correctPresses) / Double(presses) : 0
    }

    fileprivate mutating func apply(_ change: TypingSession.Change) {
      // A correction can remove text credited before this run began.
      netCorrectChars = max(0, netCorrectChars + change.netCorrectChars)
      if change.isPress {
        presses += 1
        if change.isCorrect { correctPresses += 1 }
      }
    }
  }

  public enum Mode: String, Codable, Sendable {
    case flow
    case sprint
  }

  public struct Run {
    public let mode: Mode
    public let startedAt: TimeInterval
    public fileprivate(set) var counters = Counters()
    public fileprivate(set) var keyStats = KeyStats()
    public fileprivate(set) var completed = false

    public var shouldSave: Bool {
      mode == .flow ? counters.netCorrectChars >= 50 : completed
    }
  }

  public private(set) var today = Counters()
  public private(set) var keyStats = KeyStats()
  public private(set) var run: Run?
  public private(set) var mode: Mode
  private var lastPress: TimeInterval?

  public init(mode: Mode = .flow, today: Counters = Counters(), keyStats: KeyStats = KeyStats()) {
    self.mode = mode
    self.today = today
    self.keyStats = keyStats
    self.keyStats.breakSequence()
  }

  public mutating func resetToday() {
    today = Counters()
    keyStats.breakSequence()
  }

  public func isPaused(at time: TimeInterval) -> Bool {
    guard let lastPress else { return false }
    return time - lastPress >= 10
  }

  /// A sprint's elapsed time is queried without reading a clock or adding idle gaps to today.
  public func currentCounters(at time: TimeInterval) -> Counters? {
    guard let run else { return nil }
    var counters = run.counters
    if mode == .sprint { counters.activeSeconds = max(0, time - run.startedAt) }
    return counters
  }

  /// Returns an expired Flow run so its caller can decide whether to persist it.
  @discardableResult
  public mutating func update(at time: TimeInterval) -> Run? {
    if mode == .flow, run != nil, let lastPress, time - lastPress >= 300 {
      return finishRun(at: time)
    }
    return nil
  }

  @discardableResult
  public mutating func record(_ change: TypingSession.Change, at time: TimeInterval) -> Run? {
    guard change.isPress || change.netCorrectChars != 0 else { return nil }
    let expired = update(at: time)
    today.apply(change)
    if change.isPress {
      let continuingRun = run != nil
      if run == nil { run = Run(mode: mode, startedAt: time) }
      if continuingRun, let lastPress {
        let gap = time - lastPress
        if gap >= 0 && gap < 10 {
          today.activeSeconds += gap
          if mode == .flow { run?.counters.activeSeconds += gap }
        }
      }
      lastPress = time
      keyStats.record(change, at: time)
      run?.keyStats.record(change, at: time)
    }
    run?.counters.apply(change)
    if mode == .sprint, let startedAt = run?.startedAt {
      run?.counters.activeSeconds = max(0, time - startedAt)
    }
    return expired
  }

  /// Hide ends Flow; a Sprint is eligible for history only on completion.
  @discardableResult
  public mutating func endRun(at time: TimeInterval, completed: Bool = false) -> Run? {
    lastPress = nil
    return finishRun(at: time, completed: completed)
  }

  @discardableResult
  public mutating func setMode(_ mode: Mode, at time: TimeInterval) -> Run? {
    guard self.mode != mode else { return nil }
    let ended = endRun(at: time)
    self.mode = mode
    return ended
  }

  private mutating func finishRun(at time: TimeInterval, completed: Bool = false) -> Run? {
    guard var ended = run else { return nil }
    if mode == .sprint { ended.counters.activeSeconds = max(0, time - ended.startedAt) }
    ended.completed = completed
    run = nil
    keyStats.breakSequence()
    return ended
  }
}
