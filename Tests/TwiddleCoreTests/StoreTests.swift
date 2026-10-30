import Foundation
import Testing
import TwiddleCore

struct StoreTests {
  private let instant = Date(timeIntervalSince1970: 1_793_318_400)

  private func store(_ directory: URL, date: Date? = nil) -> Store {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = date ?? instant
    return Store(directory: directory, currentDate: { now }, calendar: calendar)
  }

  private func directory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func populated(_ store: Store) -> Store.State {
    var tracker = StatsTracker()
    for (index, key) in "ababa".enumerated() {
      tracker.record(enginePress(key), at: Double(index) * 0.25)
    }
    tracker.record(enginePress("z", correct: false), at: 2)
    var state = Store.State(date: store.today)
    state.today = Store.Today(date: store.today, counters: tracker.today, bestWPM: 60)
    state.capture(tracker.keyStats)
    state.resume["code"] = Store.Resume(
      session: TypingSession(text: "a cat", caret: 3, mistakes: [0, 3]))
    state.runs = [
      .init(
        mode: .flow, source: .code, startedAt: instant,
        activeSeconds: 10, wpm: 60, accuracy: 0.9, chars: 50)
    ]
    state.panelOffset = .init(x: -20.5, y: 10.25)
    state.hintsOn = true
    state.seenIntro = true
    state.lastSprintLength = 60
    state.codePack = .typescript
    return state
  }

  @Test func missingFileReturnsFreshStateWithoutError() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let store = store(directory)
    let result = store.load()
    #expect(result.state == Store.State(date: store.today))
    #expect(result.errors.isEmpty)
    #expect(
      !FileManager.default.fileExists(atPath: directory.appendingPathComponent("state.json").path))
  }

  @Test @MainActor func versionOneFixtureRestoresWithoutDependingOnCurrentEncoder() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let fixture = """
      {
        "version": 1,
        "resume": {"words": {"text": "one two", "caret": 5, "mistakes": [1, 4]}},
        "today": {"date": "2026-10-30", "activeSeconds": 1.5, "netCorrectChars": 2,
                  "presses": 3, "correctPresses": 2, "bestWPM": 16},
        "runs": [{"mode": "flow", "source": "words", "startedAt": 1793318400000,
                  "activeSeconds": 10, "wpm": 60, "accuracy": 0.9, "chars": 50}],
        "keys": {"z": {"samples": 0, "averageMs": 0, "errorRate": 1}},
        "pairs": {"ab": {"samples": 2, "averageMs": 250, "errorRate": 0}},
        "panelOffset": {"x": -10, "y": 20}, "hintsOn": true, "seenIntro": true,
        "lastSprintLength": 60
      }
      """
    try Data(fixture.utf8).write(to: directory.appendingPathComponent("state.json"))
    let result = store(directory).load()
    #expect(result.errors.isEmpty)
    #expect(result.state.today.counters.presses == 3)
    #expect(result.state.today.bestWPM == 16)
    #expect(result.state.runs.first?.startedAt == instant)
    #expect(result.state.keyStats.keys["z"]?.errorRate == 1)
    #expect(result.state.keyStats.pairs["ab"]?.samples == 2)
    #expect(result.state.resume["words"]?.caret == 5)
    #expect(result.state.resume["words"]?.mistakes == [1, 4])
    #expect(result.state.hintsOn && result.state.seenIntro)
    #expect(result.state.panelOffset == .init(x: -10, y: 20))
    #expect(result.state.lastSprintLength == 60)
    #expect(result.state.codePack == nil)
    #expect(result.state.today.rhythm == nil)
    #expect(result.state.bestSprintWPM == nil)
    let model = PracticeModel(store: store(directory), random: FixedRandom())
    #expect(model.codePack == .all)
  }

  @Test func milestoneNineFixtureLoadsWithoutNewStatsFields() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let fixture = """
      {"version":1,"resume":{"symbols":{"text":"a[i] += 2;","caret":0,"mistakes":[]}},
       "today":{"date":"2026-10-30","activeSeconds":5,"netCorrectChars":10,
                "presses":12,"correctPresses":10,"bestWPM":24},
       "runs":[{"mode":"sprint","source":"symbols","startedAt":1793318400000,
                "activeSeconds":30,"wpm":24,"accuracy":0.9,"chars":60}],
       "keys":{"[":{"samples":20,"averageMs":240,"errorRate":0.1}},
       "pairs":{},"panelOffset":{"x":0,"y":0},"hintsOn":false,"seenIntro":true,
       "lastSprintLength":30,"codePack":"python"}
      """
    try Data(fixture.utf8).write(to: directory.appendingPathComponent("state.json"))
    let loaded = store(directory).load()
    #expect(loaded.errors.isEmpty)
    #expect(loaded.state.codePack == .python)
    #expect(loaded.state.resume["symbols"]?.text == "a[i] += 2;")
    #expect(loaded.state.runs.first?.source == .symbols)
    #expect(loaded.state.keys["["]?.samples == 20)
    #expect(loaded.state.today.rhythm == nil)
    #expect(loaded.state.bestSprintWPM == nil)
  }

  @Test func missingDirectoryIsCreatedOnSaveAndRoundTripRestoresEveryField() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try! FileManager.default.removeItem(at: directory) }
    let store = store(directory)
    #expect(store.load().errors.isEmpty)
    let state = populated(store)
    try store.save(state)
    let result = store.load()
    #expect(result.errors.isEmpty)
    #expect(result.state == state)
    #expect(result.state.keyStats.keys["z"]?.samples == 0)
    #expect(result.state.keyStats.keys["z"]?.errorRate == 1)
    var tracker = StatsTracker(today: result.state.today.counters, keyStats: result.state.keyStats)
    tracker.record(enginePress("z"), at: 2.1)
    #expect(tracker.today.presses == 7)
    #expect(tracker.today.activeSeconds == 2)
    #expect(tracker.keyStats.keys["z"]?.errorRate == 0.9)
    #expect(tracker.keyStats.keys["z"]?.samples == 0)
    let json = try JSONSerialization.jsonObject(
      with: Data(contentsOf: directory.appendingPathComponent("state.json")))
    let object = try #require(json as? [String: Any])
    #expect(object["version"] as? Int == 1)
    #expect(object["keys"] is [String: Any])
    #expect(object["resume"] is [String: Any])
  }

  @Test func invalidJSONIsQuarantined() throws {
    try assertQuarantined(Data("{broken".utf8))
  }

  @Test func validJSONWithWrongShapeIsQuarantined() throws {
    try assertQuarantined(Data("{\"version\":1,\"today\":[]}".utf8))
  }

  @Test func newerVersionIsQuarantined() throws {
    let store = store(URL(fileURLWithPath: "/unused"))
    var state = populated(store)
    state.version = Store.currentVersion + 1
    try assertQuarantined(encoded(state))
  }

  @Test func existingQuarantineIsReplaced() throws {
    try assertQuarantined(Data("not json".utf8), existingQuarantine: Data("older damage".utf8))
  }

  private func assertQuarantined(_ data: Data, existingQuarantine: Data? = nil) throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("state.json")
    let quarantine = directory.appendingPathComponent("state.corrupt.json")
    try data.write(to: file)
    try existingQuarantine?.write(to: quarantine)
    let store = store(directory)
    let result = store.load()
    #expect(result.state == Store.State(date: store.today))
    #expect(result.errors.count == 1)
    #expect(try Data(contentsOf: quarantine) == data)
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test func renameFailureStillReturnsFreshStateAndReportsBothErrors() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let quarantine = directory.appendingPathComponent("state.corrupt.json")
    try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
    try Data("keep".utf8).write(to: quarantine.appendingPathComponent("occupied"))
    let file = directory.appendingPathComponent("state.json")
    let broken = Data("broken".utf8)
    try broken.write(to: file)
    let store = store(directory)
    let result = store.load()
    #expect(result.state == Store.State(date: store.today))
    #expect(result.errors.count == 2)
    #expect((result.errors.last as NSError?)?.domain == NSPOSIXErrorDomain)
    #expect(try Data(contentsOf: file) == broken)
  }

  @Test func encodingFailurePropagatesAndPreservesExistingFile() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let store = store(directory)
    var state = populated(store)
    try store.save(state)
    let file = directory.appendingPathComponent("state.json")
    let bytes = try Data(contentsOf: file)
    state.today.bestWPM = .infinity
    #expect(throws: EncodingError.self) { try store.save(state) }
    #expect(try Data(contentsOf: file) == bytes)
  }

  @Test func directoryCreationFailurePropagatesAndPreservesBlockingFile() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("occupied")
    let bytes = Data("keep".utf8)
    try bytes.write(to: file)
    let store = store(file)
    #expect(throws: (any Error).self) { try store.save(populated(store)) }
    #expect(try Data(contentsOf: file) == bytes)
  }

  @Test func writeFailurePropagatesAndPreservesMemoryAndExistingFile() throws {
    let directory = try directory()
    defer {
      try! FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: directory.path)
      try! FileManager.default.removeItem(at: directory)
    }
    let store = store(directory)
    let original = populated(store)
    try store.save(original)
    let file = directory.appendingPathComponent("state.json")
    let bytes = try Data(contentsOf: file)
    var replacement = original
    replacement.hintsOn = false
    let before = replacement
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    #expect(throws: (any Error).self) { try store.save(replacement) }
    #expect(replacement == before)
    #expect(try Data(contentsOf: file) == bytes)
  }

  @Test func differentLocalDayResetsOnlyToday() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let yesterday = store(directory)
    var expected = populated(yesterday)
    try yesterday.save(expected)
    let tomorrow = store(directory, date: instant.addingTimeInterval(86_400))
    expected.today = .init(date: tomorrow.today)
    let result = tomorrow.load()
    #expect(result.errors.isEmpty)
    #expect(result.state == expected)
    #expect(!result.state.keyStats.keys.isEmpty)
    #expect(!result.state.runs.isEmpty)
    #expect(!result.state.resume.isEmpty)
  }

  @Test func dateUsesInjectedCalendarAtLocalMidnight() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 19_800)!
    let utcEvening = Date(timeIntervalSince1970: 1_793_386_800)
    let local = Store(
      directory: URL(fileURLWithPath: "/unused"), currentDate: { utcEvening }, calendar: calendar)
    let utc = store(URL(fileURLWithPath: "/unused"), date: utcEvening)
    #expect(local.today != utc.today)
    #expect(local.today == "2026-10-31")
  }

  @Test func historyKeepsNewestTwentyWithoutMutatingCaller() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let store = store(directory)
    var state = populated(store)
    let run = try #require(state.runs.first)
    state.runs = (0..<25).map { index in
      var copy = run
      copy.startedAt = instant.addingTimeInterval(Double(index))
      return copy
    }
    try store.save(state)
    let result = store.load()
    #expect(result.state.runs.count == 20)
    #expect(result.state.runs.first?.startedAt == instant.addingTimeInterval(24))
    #expect(result.state.runs.last?.startedAt == instant.addingTimeInterval(5))
    #expect(state.runs.count == 25)
  }

  @Test func readFailureDoesNotCrashOrHideTheError() throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("state.json"), withIntermediateDirectories: true)
    let store = store(directory)
    let result = store.load()
    #expect(result.state == Store.State(date: store.today))
    #expect(!result.errors.isEmpty)
  }

  @Test(arguments: [0, Store.currentVersion])
  func unusualValuesRoundTripWithoutDiscardingStats(version: Int) throws {
    let directory = try directory()
    defer { try! FileManager.default.removeItem(at: directory) }
    let store = store(directory)
    var state = populated(store)
    state.version = version
    state.today.netCorrectChars = -1
    state.lastSprintLength = 0
    state.resume["code"]?.caret = 100
    state.resume["code"]?.mistakes = [-1, 0, 100]
    state.keys[""] = KeyStats.Entry()
    state.keys["too long"] = KeyStats.Entry()
    try store.save(state)
    let result = store.load()
    #expect(result.errors.isEmpty)
    #expect(result.state == state)
    #expect(result.state.keyStats.keys == populated(store).keyStats.keys)
    let session = try #require(result.state.resume["code"]).session()
    #expect(session.caret == session.text.count)
    #expect(session.mistakes == [0])
  }

  private func encoded(_ state: Store.State) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    return try encoder.encode(state)
  }
}
