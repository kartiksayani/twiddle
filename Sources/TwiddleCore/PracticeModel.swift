import Foundation
import Observation

@Observable
@MainActor
public final class PracticeModel {
  public enum Command {
    case flow, sprint
    case source(ContentProvider.Source)
    case freshText, toggleHints, progress
  }

  public enum ViewState: Sendable {
    case text, progress, intro
  }

  public enum SprintState: Sendable {
    case ready, running, locked, result
  }

  public enum CapsuleContent: Sendable {
    case commands, finished
  }

  public var showsFinished: Bool { finishedUntil != nil }
  public var capsuleContent: CapsuleContent? {
    guard isVisible else { return nil }
    if commandCapsule.isVisible { return .commands }
    return showsFinished ? .finished : nil
  }

  public struct SprintResult {
    public let counters: StatsTracker.Counters
    public let mistakes: Int
    public let slowestPair: String?
    public let rhythm: Rhythm
    public let isNewBest: Bool
  }

  public private(set) var view: ViewState = .text
  public var hintsOn: Bool { state.hintsOn }
  public var seenIntro: Bool { state.seenIntro }
  public var showsHints: Bool {
    hintsOn && view == .text && !(mode == .sprint && sprintState == .result)
  }
  public var panelHeight: Double {
    PanelLayout.height(view: view, hints: showsHints)
  }
  public var hint: FingerMap.Resolved? { session.expected.flatMap(FingerMap.resolve) }
  public var progress: ProgressData { ProgressData(state: state) }

  public private(set) var source: ContentProvider.Source = .words
  public var codePack: CodePack { state.codePack ?? .all }
  public var sourceLabel: String {
    source == .code && codePack != .all ? "Code · \(codePack.label)" : source.label
  }
  public var mode: StatsTracker.Mode { stats.mode }
  public private(set) var sprintState: SprintState = .ready
  public private(set) var result: SprintResult?
  public private(set) var contentNote: String?
  public private(set) var sprintElapsed: TimeInterval = 0
  public private(set) var sprintLength: Int = 30
  public var hotkey: Hotkey? {
    if let settings { return settings.hotkey }
    return .standard
  }
  public var ghostOffset: Double? {
    guard isVisible, view == .text, mode == .sprint, sprintState == .running,
      let best = state.bestSprintWPM?[sprintLength], best.isFinite, best >= 0
    else { return nil }
    let offset = sprintElapsed * best * 5 / 60
    let current = lines.lastIndex(where: { $0.lowerBound <= session.caret }) ?? 0
    let visible = lines.dropFirst(current).prefix(2)
    guard let first = visible.first, let last = visible.last,
      offset >= Double(first.lowerBound), offset < Double(last.upperBound)
    else { return nil }
    return offset
  }

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
    (ContentProvider.Source, CodePack, KeyStats) -> ContentProvider.Content
  @ObservationIgnored private let log: (any Error) -> Void
  @ObservationIgnored private var mistakes: TypingSession.MistakeMode
  private let settings: Settings?
  @ObservationIgnored private var noteUntil: TimeInterval?
  @ObservationIgnored private var flowSessions: [ContentProvider.Source: TypingSession] = [:]
  @ObservationIgnored private var flowNotes: [ContentProvider.Source: String] = [:]
  @ObservationIgnored private var lockedUntil: TimeInterval?
  @ObservationIgnored private var completedSprint: SprintResult?
  private var commandCapsule = CommandCapsule()
  private var finishedUntil: TimeInterval?

  public init<R: RandomNumberGenerator>(
    store: Store, random: R, mistakes: TypingSession.MistakeMode = .strict,
    settings: Settings? = nil,
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
    self.settings = settings
    var random = random
    let provider = ContentProvider()
    content = { provider.content(for: $0, keyStats: $2, codePack: $1, using: &random) }
    let loaded = store.load()
    state = loaded.state
    stats = StatsTracker(
      today: loaded.state.today.counters, keyStats: loaded.state.keyStats,
      todayRhythm: loaded.state.today.rhythm ?? Rhythm())
    if state.bestSprintWPM == nil {
      var bests: [Int: Double] = [:]
      for run in state.runs where run.mode == .sprint {
        let length = [15, 30, 60].min {
          abs(Double($0) - run.activeSeconds) < abs(Double($1) - run.activeSeconds)
        }!
        bests[length] = max(bests[length] ?? 0, run.wpm)
      }
      state.bestSprintWPM = bests
    }
    if ![15, 30, 60].contains(state.lastSprintLength) { state.lastSprintLength = 30 }
    if let settings {
      source = settings.defaultSource
      stats.setMode(settings.defaultMode, at: now())
    }
    sprintLength = state.lastSprintLength
    for error in loaded.errors { log(error) }
  }

  public func launch() {
    guard !seenIntro, !isVisible else { return }
    summon()
    view = .intro
  }

  public func summon() {
    guard !isVisible else { return }
    mistakes = settings?.mistakes ?? mistakes
    view = .text
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
    let time = now()
    settleElapsedSprint(at: time)
    guard isVisible else { return }
    if view == .intro { dismissIntro() }
    if view == .progress {
      view = .text
      if case .backspace = input { return }
      if case .deleteWord = input { return }
    }
    if mode == .sprint {
      if sprintState == .result {
        if case .character("\n") = input { readySprint() }
        return
      }
      guard sprintState != .locked else { return }
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
      session.append(content(source, codePack, stats.keyStats).text)
      cacheLayout()
    }
  }

  public func handle(_ command: Command) {
    let time = now()
    settleElapsedSprint(at: time)
    guard isVisible else { return }
    if case .toggleHints = command {
      setHints(!hintsOn)
      return
    }
    if case .progress = command {
      guard view != .intro, mode == .flow || sprintState == .ready else { return }
      updateStats(at: time)
      state.capture(stats.keyStats)
      view = view == .progress ? .text : .progress
      return
    }
    guard view != .intro else { return }
    view = .text
    let cyclesCode: Bool
    if case .source(.code) = command { cyclesCode = source == .code } else { cyclesCode = false }
    if case .flow = command, mode == .flow { return }
    if case .source(let source) = command, mode == .flow && source == self.source && !cyclesCode {
      return
    }
    updateStats(at: time)
    switch command {
    case .toggleHints, .progress: break
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
        setSprintLength(sprintLength == 15 ? 30 : sprintLength == 30 ? 60 : 15)
      }
      readySprint()
    case .source(let source):
      if cyclesCode {
        endCurrentRun(at: time)
        state.codePack = codePack.next
        flowSessions[.code] = nil
        flowNotes[.code] = nil
        state.resume["code"] = nil
        if mode == .flow { session = newSession() } else { readySprint() }
        flowSessions[.code] = session
        state.resume["code"] = Store.Resume(session: session)
        break
      }
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
    let time = now()
    settleElapsedSprint(at: time)
    guard isVisible else { return }
    commandCapsule.handle(.tick, at: time)
    if let finishedUntil, time >= finishedUntil { self.finishedUntil = nil }
    if let noteUntil, time >= noteUntil {
      resumedWord = nil
      self.noteUntil = nil
    }
    updateStats(at: time)
    if mode == .sprint {
      if sprintState == .running, let run = stats.run {
        sprintElapsed = min(Double(sprintLength), max(0, time - run.startedAt))
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
    clearCapsule()
    finish()
    flowSessions.removeAll()
    flowNotes.removeAll()
    isVisible = false
  }

  public func quit() {
    clearCapsule()
    finish()
    isVisible = false
  }

  public func handle(_ url: URL) {
    guard isVisible, WaitSignal(url: url) == .done else { return }
    finishedUntil = now() + 10
  }

  public func handleCapsule(_ event: CommandCapsule.Event) {
    guard isVisible else { return }
    commandCapsule.handle(event, at: now())
  }

  private func clearCapsule() {
    finishedUntil = nil
    commandCapsule.handle(.dismiss, at: now())
  }

  public func setHints(_ enabled: Bool) {
    updateStats(at: now())
    state.hintsOn = enabled
    save()
  }

  public func setSprintLength(_ length: Int) {
    guard [15, 30, 60].contains(length) else { return }
    state.lastSprintLength = length
    save()
  }

  public func setPanelOffset(_ offset: Store.PanelOffset) {
    guard offset.x.isFinite, offset.y.isFinite else { return }
    state.panelOffset = offset
    save()
  }

  public func openProgress() {
    if isVisible { hide() }
    summon()
    if !seenIntro { dismissIntro() }
    state.capture(stats.keyStats)
    view = .progress
  }

  public func refreshToday() { resetDayIfNeeded() }

  private func dismissIntro() {
    resetDayIfNeeded()
    state.seenIntro = true
    view = .text
    save()
  }

  private func finish() {
    if view == .intro { dismissIntro() }
    let time = now()
    settleElapsedSprint(at: time)
    endCurrentRun(at: time)
    resetDayIfNeeded()
    save()
  }

  private func settleElapsedSprint(at time: TimeInterval) {
    guard mode == .sprint, sprintState == .running, let run = stats.run,
      time >= run.startedAt + Double(sprintLength),
      let completed = stats.endRun(at: run.startedAt + Double(sprintLength), completed: true)
    else { return }
    sprintElapsed = Double(sprintLength)
    let previousBest = state.bestSprintWPM?[sprintLength]
    let isNewBest = previousBest.map { completed.counters.wpm > $0 } ?? false
    state.bestSprintWPM?[sprintLength] = max(previousBest ?? 0, completed.counters.wpm)
    completedSprint = SprintResult(
      counters: completed.counters, mistakes: session.mistakes.count,
      slowestPair: completed.keyStats.slowestPair?.letters, rhythm: completed.rhythm,
      isNewBest: isNewBest)
    sprintState = .locked
    lockedUntil = time + 0.6
    resetDayIfNeeded()
    capture(completed, at: time)
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
      date: store.today, counters: stats.today, bestWPM: state.today.bestWPM,
      rhythm: stats.todayRhythm.count > 0 ? stats.todayRhythm : nil)
  }

  private func clearResumeNote() {
    resumedWord = nil
    noteUntil = nil
  }

  private func newSession() -> TypingSession {
    let next = content(source, codePack, stats.keyStats)
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
    if session.needsExtension { session.append(content(source, codePack, stats.keyStats).text) }
  }

  private func readySprint() {
    sprintLength = state.lastSprintLength
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
