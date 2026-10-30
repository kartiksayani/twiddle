import Foundation
import Observation

@Observable
@MainActor
public final class PracticeModel {
  public enum Command {
    case flow, sprint
    case source(ContentProvider.Source)
    case freshText
  }

  public enum SprintState: Sendable {
    case ready, running, locked, result
  }

  public struct SprintResult {
    public let counters: StatsTracker.Counters
    public let mistakes: Int
    public let slowestPair: String?
  }

  public private(set) var source: ContentProvider.Source = .words
  public var mode: StatsTracker.Mode { stats.mode }
  public private(set) var sprintState: SprintState = .ready
  public private(set) var result: SprintResult?
  public private(set) var contentNote: String?
  public private(set) var sprintElapsed: TimeInterval = 0
  public var sprintLength: Int { state.lastSprintLength }
  public var sprintRemaining: Int { max(0, Int(ceil(Double(sprintLength) - sprintElapsed))) }
  public var headerCounters: StatsTracker.Counters {
    mode == .flow
      ? stats.today
      : result?.counters ?? completedSprint?.counters ?? stats.currentCounters(
        at: (stats.run?.startedAt ?? 0) + sprintElapsed) ?? .init()
  }

  public private(set) var session = TypingSession(text: "")
  public private(set) var characters: [Character] = []
  public private(set) var lines: [Range<Int>] = []
  public private(set) var stats: StatsTracker
  public private(set) var state: Store.State
  public private(set) var isVisible = false
  public private(set) var isPaused = false
  public private(set) var resumedWord: String?
  public var caretBlinks: Bool {
    mode == .flow ? isPaused || stats.run == nil : sprintState == .ready
  }

  @ObservationIgnored private let store: Store
  @ObservationIgnored private let now: () -> TimeInterval
  @ObservationIgnored private let date: () -> Date
  @ObservationIgnored private let content:
    (ContentProvider.Source, KeyStats) -> ContentProvider.Content
  @ObservationIgnored private let log: (any Error) -> Void
  @ObservationIgnored private let mistakes: TypingSession.MistakeMode
  @ObservationIgnored private var noteUntil: TimeInterval?
  @ObservationIgnored private var flowSessions: [ContentProvider.Source: TypingSession] = [:]
  @ObservationIgnored private var flowNotes: [ContentProvider.Source: String] = [:]
  @ObservationIgnored private var lockedUntil: TimeInterval?
  @ObservationIgnored private var completedSprint: SprintResult?

  public init<R: RandomNumberGenerator>(
    store: Store, random: R, mistakes: TypingSession.MistakeMode = .strict,
    now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    date: @escaping () -> Date = { Date() },
    log: @escaping (any Error) -> Void = {
      NSLog("Twiddle storage error: %@", String(describing: $0))
    }
  ) {
    self.store = store
    self.now = now
    self.date = date
    self.log = log
    self.mistakes = mistakes
    var random = random
    let provider = ContentProvider()
    content = { provider.content(for: $0, keyStats: $1, using: &random) }
    let loaded = store.load()
    state = loaded.state
    stats = StatsTracker(today: loaded.state.today.counters, keyStats: loaded.state.keyStats)
    if ![15, 30, 60].contains(state.lastSprintLength) { state.lastSprintLength = 30 }
    for error in loaded.errors { log(error) }
  }

  public func summon() {
    guard !isVisible else { return }
    resetDayIfNeeded()
    if mode == .sprint {
      readySprint()
    } else {
      restoreFlow(showNote: true)
    }
    cacheLayout()
    isPaused = false
    isVisible = true
  }

  public func handle(_ input: TypingSession.Input) {
    guard isVisible else { return }
    let time = now()
    if mode == .sprint {
      if sprintState == .result {
        if case .character("\n") = input { readySprint() }
        return
      }
      guard sprintState != .locked else { return }
      if let run = stats.run, time >= run.startedAt + Double(sprintLength) { return }
    }
    updateStats(at: time)
    let change = session.handle(input)
    clearResumeNote()
    stats.record(change, at: time)
    if change.isPress {
      isPaused = false
      if mode == .sprint { sprintState = .running }
    }
    syncToday()
    if session.needsExtension {
      session.append(content(source, stats.keyStats).text)
      cacheLayout()
    }
  }

  public func handle(_ command: Command) {
    guard isVisible else { return }
    if case .flow = command, mode == .flow { return }
    if case .source(let source) = command, mode == .flow && source == self.source { return }
    let time = now()
    updateStats(at: time)
    switch command {
    case .flow:
      endCurrentRun(at: time)
      stats.setMode(.flow, at: time)
      restoreFlowSession()
      result = nil
    case .sprint:
      let cycle = mode == .sprint && sprintState == .ready
      if mode == .flow { rememberFlow() }
      endCurrentRun(at: time)
      stats.setMode(.sprint, at: time)
      if cycle {
        state.lastSprintLength = sprintLength == 15 ? 30 : sprintLength == 30 ? 60 : 15
      }
      readySprint()
    case .source(let source):
      if mode == .flow {
        rememberFlow()
        endCurrentRun(at: time)
        self.source = source
        restoreFlowSession()
      } else {
        endCurrentRun(at: time)
        self.source = source
        readySprint()
      }
    case .freshText:
      if mode == .sprint {
        endCurrentRun(at: time)
        readySprint()
      } else {
        session = newSession()
      }
    }
    clearResumeNote()
    isPaused = false
    cacheLayout()
    save()
  }

  public func tick() {
    guard isVisible else { return }
    let time = now()
    if let noteUntil, time >= noteUntil {
      resumedWord = nil
      self.noteUntil = nil
    }
    updateStats(at: time)
    if mode == .sprint {
      if sprintState == .running, let run = stats.run {
        sprintElapsed = min(Double(sprintLength), max(0, time - run.startedAt))
        if sprintElapsed >= Double(sprintLength),
          let completed = stats.endRun(
            at: run.startedAt + Double(sprintLength), completed: true)
        {
          completedSprint = SprintResult(
            counters: completed.counters, mistakes: session.mistakes.count,
            slowestPair: completed.keyStats.slowestPair?.letters)
          sprintState = .locked
          lockedUntil = time + 0.6
          capture(completed, at: time)
          save()
        }
      } else if sprintState == .locked, let lockedUntil, time >= lockedUntil,
        let completedSprint
      {
        result = completedSprint
        sprintState = .result
        self.completedSprint = nil
      }
    } else {
      isPaused = stats.isPaused(at: time)
    }
  }

  public func hide() {
    guard isVisible else { return }
    finish()
    isVisible = false
  }

  public func quit() {
    finish()
    isVisible = false
  }

  private func finish() {
    let time = now()
    endCurrentRun(at: time)
    resetDayIfNeeded()
    save()
  }

  private func updateStats(at time: TimeInterval) {
    let ended = stats.update(at: time)
    if let ended { capture(ended, at: time) }
    resetDayIfNeeded()
    if ended != nil { save() }
  }

  private func capture(_ run: StatsTracker.Run, at time: TimeInterval) {
    guard run.shouldSave else { return }
    let counters = run.counters
    state.today.bestWPM = max(state.today.bestWPM, counters.wpm)
    state.runs.insert(
      Store.Run(
        mode: run.mode, source: source, startedAt: date().addingTimeInterval(run.startedAt - time),
        activeSeconds: counters.activeSeconds, wpm: counters.wpm, accuracy: counters.accuracy,
        chars: counters.netCorrectChars), at: 0)
    state.runs = Array(state.runs.sorted { $0.startedAt > $1.startedAt }.prefix(20))
  }

  private func save() {
    if mode == .flow { rememberFlow() }
    for (source, session) in flowSessions where !session.text.isEmpty {
      state.resume[source.rawValue] = Store.Resume(session: session)
    }
    syncToday()
    state.capture(stats.keyStats)
    do {
      try store.save(state)
    } catch {
      log(error)
    }
  }

  private func endCurrentRun(at time: TimeInterval) {
    if let ended = stats.endRun(at: time) { capture(ended, at: time) }
    completedSprint = nil
  }

  private func syncToday() {
    state.today = Store.Today(
      date: store.today, counters: stats.today, bestWPM: state.today.bestWPM)
  }

  private func clearResumeNote() {
    resumedWord = nil
    noteUntil = nil
  }

  private func newSession() -> TypingSession {
    let next = content(source, stats.keyStats)
    contentNote = next.note
    return TypingSession(text: next.text, mode: mistakes)
  }

  private func rememberFlow() {
    guard !session.text.isEmpty else { return }
    flowSessions[source] = session
    flowNotes[source] = contentNote
  }

  private func restoreFlowSession() {
    if let saved = flowSessions[source] {
      session = saved
      contentNote = flowNotes[source]
    } else {
      restoreFlow(showNote: false)
    }
  }

  private func restoreFlow(showNote: Bool) {
    if let resume = state.resume[source.rawValue], !resume.text.isEmpty {
      session = resume.session(mode: mistakes)
      session.resumeAtWordStart()
      if showNote {
        resumedWord = String(session.text.dropFirst(session.caret).prefix { !$0.isWhitespace })
        noteUntil = now() + 2
      }
      contentNote =
        source == .weakKeys && stats.keyStats.weakestKeys.count < 5
        ? ContentProvider.insufficientDataNote : nil
    } else {
      session = newSession()
      clearResumeNote()
    }
    if session.needsExtension { session.append(content(source, stats.keyStats).text) }
  }

  private func readySprint() {
    session = newSession()
    sprintState = .ready
    sprintElapsed = 0
    lockedUntil = nil
    completedSprint = nil
    result = nil
    clearResumeNote()
    cacheLayout()
  }

  private func resetDayIfNeeded() {
    guard state.today.date != store.today else { return }
    stats.resetToday()
    state.today = Store.Today(date: store.today)
  }

  private func cacheLayout() {
    characters = Array(session.text)
    lines = TextLayout.layout(session.text)
  }
}
