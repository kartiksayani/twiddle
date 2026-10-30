import Foundation
import Observation

@Observable
@MainActor
public final class PracticeModel {
  public private(set) var session = TypingSession(text: "")
  public private(set) var characters: [Character] = []
  public private(set) var lines: [Range<Int>] = []
  public private(set) var stats: StatsTracker
  public private(set) var state: Store.State
  public private(set) var isVisible = false
  public private(set) var isPaused = false
  public private(set) var resumedWord: String?
  public var caretBlinks: Bool { isPaused || stats.run == nil }

  @ObservationIgnored private let store: Store
  @ObservationIgnored private let now: () -> TimeInterval
  @ObservationIgnored private let date: () -> Date
  @ObservationIgnored private let content: () -> String
  @ObservationIgnored private let log: (any Error) -> Void
  @ObservationIgnored private let mistakes: TypingSession.MistakeMode
  @ObservationIgnored private var noteUntil: TimeInterval?

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
    content = { provider.content(for: .words, using: &random).text }
    let loaded = store.load()
    state = loaded.state
    stats = StatsTracker(today: loaded.state.today.counters, keyStats: loaded.state.keyStats)
    for error in loaded.errors { log(error) }
  }

  public func summon() {
    guard !isVisible else { return }
    resetDayIfNeeded()
    if let resume = state.resume[ContentProvider.Source.words.rawValue], !resume.text.isEmpty {
      session = resume.session(mode: mistakes)
      session.resumeAtWordStart()
      resumedWord = String(session.text.dropFirst(session.caret).prefix { !$0.isWhitespace })
      noteUntil = now() + 2
    } else {
      session = TypingSession(text: content(), mode: mistakes)
      resumedWord = nil
      noteUntil = nil
    }
    if session.needsExtension { session.append(content()) }
    cacheLayout()
    isPaused = false
    isVisible = true
  }

  public func handle(_ input: TypingSession.Input) {
    guard isVisible else { return }
    let time = now()
    updateStats(at: time)
    let change = session.handle(input)
    resumedWord = nil
    noteUntil = nil
    stats.record(change, at: time)
    if change.isPress { isPaused = false }
    state.today = Store.Today(
      date: store.today, counters: stats.today, bestWPM: state.today.bestWPM)
    if session.needsExtension {
      session.append(content())
      cacheLayout()
    }
  }

  public func tick() {
    guard isVisible else { return }
    let time = now()
    if let noteUntil, time >= noteUntil {
      resumedWord = nil
      self.noteUntil = nil
    }
    isPaused = stats.isPaused(at: time)
    updateStats(at: time)
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
    if let ended = stats.endRun(at: time) { capture(ended, at: time) }
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
        mode: .flow, source: .words, startedAt: date().addingTimeInterval(run.startedAt - time),
        activeSeconds: counters.activeSeconds, wpm: counters.wpm, accuracy: counters.accuracy,
        chars: counters.netCorrectChars), at: 0)
    state.runs = Array(state.runs.sorted { $0.startedAt > $1.startedAt }.prefix(20))
  }

  private func save() {
    if !session.text.isEmpty {
      state.resume[ContentProvider.Source.words.rawValue] = Store.Resume(session: session)
    }
    state.capture(stats.keyStats)
    do {
      try store.save(state)
    } catch {
      log(error)
    }
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
