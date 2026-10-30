import Foundation
import Testing
import TwiddleCore

@MainActor
private final class PracticeFixture {
  var time = 0.0
  var date = Date(timeIntervalSince1970: 1_790_000_000)
  var errors = 0
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  lazy var store = Store(directory: directory, currentDate: { self.date })
  lazy var model = PracticeModel(
    store: store, random: FixedRandom(), now: { self.time },
    date: { self.date.addingTimeInterval(self.time) }, log: { _ in self.errors += 1 })

  func seed(caret: Int = 0, marks: Set<Int> = [], runs: Int = 0, bestWPM: Double = 0) throws {
    var state = Store.State(date: store.today)
    state.today.bestWPM = bestWPM
    state.resume["words"] = Store.Resume(
      session: TypingSession(
        text: String(repeating: "alpha beta gamma ", count: 50), caret: caret, mistakes: marks))
    state.runs = (0..<runs).map { index in
      Store.Run(
        mode: .flow, source: .words, startedAt: date.addingTimeInterval(-Double(index + 1)),
        activeSeconds: 10, wpm: 60, accuracy: 1, chars: 50)
    }
    try store.save(state)
  }

  func type(_ count: Int) {
    for _ in 0..<count {
      model.handle(.character(model.session.expected!))
      time += 0.1
    }
  }

  func clean() throws {
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }
}

private struct FixedRandom: RandomNumberGenerator {
  mutating func next() -> UInt64 { 0xA123_4567_89AB_CDEF }
}

@MainActor
struct PracticeModelTests {
  @Test func freshSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    #expect(!f.model.isVisible)
    #expect(f.model.session.text.isEmpty)
    f.model.summon()
    #expect(f.model.isVisible)
    #expect(f.model.session.text.count >= 600)
    #expect(f.model.resumedWord == nil)
    #expect(f.model.caretBlinks)
  }

  @Test func runSpanningMidnightStillExpiresAfterIdle() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    f.date = f.date.addingTimeInterval(86_400)
    f.model.tick()
    #expect(f.model.stats.today.presses == 0)
    #expect(f.model.state.runs.isEmpty)
    f.time += 300
    f.model.tick()
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.isPaused)
  }

  @Test func visibleAfterTypingThenSummonKeepsCaretAndToday() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 6)
    f.model.summon()
    f.type(2)
    let today = f.model.stats.today
    let storedToday = f.model.state.today
    let text = f.model.session.text
    #expect(f.model.isVisible)
    #expect(f.model.session.caret == 8)
    #expect(today.presses == 2)
    f.model.summon()
    #expect(f.model.isVisible)
    #expect(f.model.session.caret == 8)
    #expect(f.model.stats.today == today)
    #expect(f.model.state.today == storedToday)
    #expect(f.model.session.text == text)
    #expect(f.model.resumedWord == nil)
  }

  @Test func savedMidWordSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 8, marks: [0, 7, 9])
    f.model.summon()
    #expect(f.model.session.caret == 6)
    #expect(f.model.session.mistakes == [0])
    #expect(f.model.resumedWord == "beta")
    #expect(f.model.caretBlinks)
  }

  @Test func savedWordStartSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 6, marks: [0, 6])
    f.model.summon()
    #expect(f.model.session.caret == 6)
    #expect(f.model.session.mistakes == [0])
    #expect(f.model.resumedWord == "beta")
  }

  @Test func firstKeyClearsNoteAndCounts() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 8)
    f.model.summon()
    f.type(1)
    #expect(f.model.resumedWord == nil)
    #expect(f.model.session.caret == 7)
    #expect(f.model.stats.today.presses == 1)
    #expect(!f.model.caretBlinks)
  }

  @Test func noteExpiresAtTwoSeconds() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 8)
    f.model.summon()
    f.time = 1.999
    f.model.tick()
    #expect(f.model.resumedWord == "beta")
    f.time = 2
    f.model.tick()
    #expect(f.model.resumedWord == nil)
  }

  @Test func pendingDroppedOnHideAndSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 6, marks: [0])
    f.model.summon()
    f.type(2)
    f.model.handle(.character("x"))
    #expect(f.model.session.pending == "x")
    f.model.hide()
    f.model.summon()
    #expect(f.model.session.caret == 6)
    #expect(f.model.session.pending == nil)
    #expect(f.model.session.mistakes == [0])
  }

  @Test func typingUpdatesEngineTodayAndKeysWithoutSaving() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed()
    let saved = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    f.model.summon()
    f.type(1)
    f.model.handle(.character("x"))
    #expect(f.model.session.caret == 1)
    #expect(f.model.session.pending == "x")
    #expect(f.model.stats.today.presses == 2)
    #expect(f.model.stats.today.correctPresses == 1)
    #expect(f.model.stats.today.netCorrectChars == 1)
    #expect(f.model.stats.today.activeSeconds == 0.1)
    #expect(f.model.state.today.bestWPM == 0)
    #expect(f.model.stats.keyStats.keys["l"]?.errorRate == 1)
    #expect(try Data(contentsOf: f.directory.appendingPathComponent("state.json")) == saved)
  }

  @Test func extensionKeepsCaretAndMarks() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(marks: [])
    f.model.summon()
    let oldText = f.model.session.text
    f.model.handle(.character("x"))
    let count = oldText.count - 299
    f.type(count)
    #expect(f.model.session.text.hasPrefix(oldText))
    #expect(f.model.session.text.count > oldText.count)
    #expect(f.model.session.caret == count)
    #expect(f.model.session.mistakes == [0])
    #expect(f.model.lines == TextLayout.layout(f.model.session.text))
    #expect(f.model.characters == Array(f.model.session.text))
  }

  @Test func underTenSecondsIsNotPaused() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(1)
    f.time = 9.999
    f.model.tick()
    #expect(!f.model.isPaused)
  }

  @Test func tenSecondsPausesAndBlinks() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(1)
    f.time = 10
    f.model.tick()
    #expect(f.model.isPaused)
    #expect(f.model.caretBlinks)
  }

  @Test func pausedKeyExcludesIdleTime() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(2)
    let active = f.model.stats.today.activeSeconds
    f.time = 20
    f.model.tick()
    f.type(1)
    #expect(!f.model.isPaused)
    #expect(!f.model.caretBlinks)
    #expect(f.model.stats.today.activeSeconds == active)
  }

  @Test func fiveMinutesEndsRunAndSavesWhilePaused() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    f.time += 300
    f.model.tick()
    #expect(f.model.isVisible)
    #expect(f.model.isPaused)
    #expect(f.model.caretBlinks)
    #expect(f.model.stats.run == nil)
    #expect(f.model.state.runs.count == 1)
    #expect(f.store.load().state.runs == f.model.state.runs)
    f.model.tick()
    f.model.hide()
    #expect(f.model.state.runs.count == 1)
  }

  @Test func keyAfterUntickedExpirySavesOldRunBeforeCountingNewPress() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    let caret = f.model.session.caret
    f.time += 300
    f.type(1)
    let saved = f.store.load().state
    #expect(saved.runs.count == 1)
    #expect(saved.runs.first?.chars == 50)
    #expect(saved.today.presses == 50)
    #expect(f.model.stats.today.presses == 51)
    #expect(f.model.session.caret == caret + 1)
    #expect(f.model.stats.run?.counters.presses == 1)
    #expect(!f.model.isPaused)
    f.model.hide()
    #expect(f.store.load().state.today.presses == 51)
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func shortRunKeepsTodayAndKeysWithoutHistory() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(49)
    f.model.hide()
    let saved = f.store.load().state
    #expect(saved.runs.isEmpty)
    #expect(saved.today.bestWPM == 0)
    #expect(saved.today.netCorrectChars == 49)
    #expect(!saved.keys.isEmpty)
    #expect(saved.keyStats.pairs == f.model.stats.keyStats.pairs)
  }

  @Test func fastOpeningBurstDoesNotRaiseBestWPM() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(2)
    #expect(f.model.stats.today.wpm == 240)
    #expect(f.model.state.today.bestWPM == 0)
  }

  @Test func savedRunRaisesBestWPMToItsFinalSpeed() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(2)
    f.model.hide()
    f.model.summon()
    f.type(50)
    let run = try #require(f.model.stats.run)
    #expect(run.counters.wpm != f.model.stats.today.wpm)
    #expect(f.model.state.today.bestWPM == 0)
    f.model.hide()
    let saved = f.store.load().state
    #expect(saved.today.bestWPM == run.counters.wpm)
    #expect(saved.today.bestWPM > 0)
    #expect(saved.runs.first?.wpm == saved.today.bestWPM)
  }

  @Test(arguments: [49, 50]) func slowerRunPreservesExistingBestWPM(characters: Int) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(bestWPM: 300)
    f.model.summon()
    f.type(characters)
    #expect(f.model.state.today.bestWPM == 300)
    f.model.hide()
    #expect(f.store.load().state.today.bestWPM == 300)
  }

  @Test func eligibleRunKeepsNewestTwenty() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(runs: 20)
    f.model.summon()
    f.type(50)
    f.model.hide()
    f.model.hide()
    let saved = f.store.load().state
    #expect(saved.runs.count == 20)
    #expect(saved.runs.first?.chars == 50)
    #expect(saved.runs.first?.startedAt == f.date)
    #expect(saved.runs.last?.startedAt == f.date.addingTimeInterval(-19))
  }

  @Test func hiddenDayChangeResetsTodayOnly() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    f.model.hide()
    let keys = f.model.stats.keyStats.keys
    let runs = f.model.state.runs
    f.date = f.date.addingTimeInterval(86400)
    f.model.summon()
    #expect(f.model.stats.today == StatsTracker.Counters())
    #expect(f.model.stats.keyStats.keys == keys)
    #expect(f.model.state.runs == runs)
    #expect(f.model.state.today.date == f.store.today)
    #expect(f.model.state.today.bestWPM == 0)
  }

  @Test func typingDayChangeResetsThenCountsKey() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(2)
    let keys = f.model.stats.keyStats.keys
    f.date = f.date.addingTimeInterval(86400)
    f.type(1)
    #expect(f.model.stats.today.presses == 1)
    #expect(f.model.stats.today.netCorrectChars == 1)
    #expect(f.model.stats.today.activeSeconds == 0.1)
    #expect(f.model.stats.run?.counters.presses == 3)
    #expect(f.model.stats.keyStats.keys.count >= keys.count)
  }

  @Test(arguments: [false, true])
  func visibleDayChangeTickKeepsKeysAndRuns(expired: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(runs: 1, bestWPM: 300)
    f.model.summon()
    f.type(50)
    let keys = f.model.stats.keyStats.keys
    let pairs = f.model.stats.keyStats.pairs
    let runs = f.model.state.runs
    #expect(f.model.stats.today.presses == 50)
    f.date = f.date.addingTimeInterval(86400)
    if expired { f.time += 300 }
    f.model.tick()
    #expect(f.model.isVisible)
    #expect(f.model.stats.today == StatsTracker.Counters())
    #expect(f.model.state.today == Store.Today(date: f.store.today))
    #expect(f.model.stats.keyStats.keys == keys)
    #expect(f.model.stats.keyStats.pairs == pairs)
    if expired {
      #expect(f.model.stats.run == nil)
      #expect(f.model.state.runs.count == 2)
      #expect(f.model.state.runs.first?.chars == 50)
      #expect(Array(f.model.state.runs.dropFirst()) == runs)
      #expect(f.store.load().state == f.model.state)
    } else {
      #expect(f.model.stats.run?.counters.presses == 50)
      #expect(f.model.state.runs == runs)
    }
    f.model.hide()
    #expect(f.model.state.runs.count == 2)
    #expect(f.store.load().state == f.model.state)
  }

  @Test(arguments: [false, true])
  func dayChangeThenHideOrQuitKeepsKeysAndRuns(quitting: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(runs: 1, bestWPM: 300)
    f.model.summon()
    f.type(50)
    let keys = f.model.stats.keyStats.keys
    let pairs = f.model.stats.keyStats.pairs
    let runs = f.model.state.runs
    #expect(f.model.stats.today.presses == 50)
    f.date = f.date.addingTimeInterval(86400)
    if quitting { f.model.quit() } else { f.model.hide() }
    #expect(!f.model.isVisible)
    #expect(f.model.stats.run == nil)
    #expect(f.model.stats.today == StatsTracker.Counters())
    #expect(f.model.state.today == Store.Today(date: f.store.today))
    #expect(f.model.stats.keyStats.keys == keys)
    #expect(f.model.stats.keyStats.pairs == pairs)
    #expect(f.model.state.runs.count == 2)
    #expect(f.model.state.runs.first?.chars == 50)
    #expect(Array(f.model.state.runs.dropFirst()) == runs)
    #expect(f.store.load().state == f.model.state)
  }

  @Test func failedSaveLogsAndRetriesWithoutLosingMemory() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    try Data().write(to: f.directory)
    f.model.hide()
    #expect(f.errors == 1)
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.stats.today.presses == 50)
    let resume = f.model.state.resume["words"]
    try FileManager.default.removeItem(at: f.directory)
    f.model.summon()
    #expect(f.model.session.caret <= resume!.caret)
    f.model.hide()
    #expect(f.errors == 1)
    #expect(f.store.load().state.today.presses == 50)
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func visibleQuitEndsAndSaves() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.type(50)
    f.model.quit()
    #expect(!f.model.isVisible)
    #expect(f.model.stats.run == nil)
    #expect(f.store.load().state.runs.count == 1)
    f.model.quit()
    #expect(f.store.load().state.runs.count == 1)
  }

  @Test func hiddenInputIsIgnoredAndLoadErrorsLogged() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try FileManager.default.createDirectory(at: f.directory, withIntermediateDirectories: true)
    try Data("broken".utf8).write(to: f.directory.appendingPathComponent("state.json"))
    let state = f.model.state
    f.model.handle(.character("a"))
    #expect(!f.model.isVisible)
    #expect(f.model.session.text.isEmpty)
    #expect(f.model.state == state)
    #expect(f.errors == 1)
    #expect(f.model.stats.today.presses == 0)
    f.model.quit()
    #expect(f.store.load().state.resume.isEmpty)
  }

  @Test func hiddenAfterHideThenTickKeepsStateAndSavedFile() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed(caret: 6)
    f.model.summon()
    f.type(2)
    f.model.hide()
    let state = f.model.state
    let today = f.model.stats.today
    let keys = f.model.stats.keyStats.keys
    let pairs = f.model.stats.keyStats.pairs
    let text = f.model.session.text
    let caret = f.model.session.caret
    let saved = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    #expect(!f.model.isVisible)
    #expect(caret == 8)
    #expect(today.presses == 2)
    f.date = f.date.addingTimeInterval(86400)
    f.time += 300
    f.model.tick()
    #expect(!f.model.isVisible)
    #expect(!f.model.isPaused)
    #expect(f.model.stats.run == nil)
    #expect(f.model.state == state)
    #expect(f.model.stats.today == today)
    #expect(f.model.stats.keyStats.keys == keys)
    #expect(f.model.stats.keyStats.pairs == pairs)
    #expect(f.model.session.text == text)
    #expect(f.model.session.caret == caret)
    #expect(f.model.session.pending == nil)
    #expect(f.model.session.mistakes.isEmpty)
    #expect(f.model.resumedWord == nil)
    #expect(try Data(contentsOf: f.directory.appendingPathComponent("state.json")) == saved)
  }

  @Test func forgivingValueIsAppliedOnSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    let model = PracticeModel(store: f.store, random: FixedRandom(), mistakes: .forgiving)
    model.summon()
    model.handle(.character("!"))
    #expect(model.session.caret == 1)
    model.handle(.backspace)
    #expect(model.session.caret == 0)
    #expect(model.session.mistakes.isEmpty)
  }
}
