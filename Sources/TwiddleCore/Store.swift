import Foundation

public struct Store {
  public static let currentVersion = 1

  public struct Resume: Codable, Equatable, Sendable {
    public var text: String
    public var caret: Int
    public var mistakes: Set<Int>

    public init(session: TypingSession) {
      let characters = Array(session.text)
      let start =
        TextLayout.layout(session.text).last(where: { $0.lowerBound <= session.caret })?.lowerBound
        ?? 0
      text = String(characters[start...])
      caret = session.caret - start
      mistakes = Set(session.mistakes.filter { $0 >= start }.map { $0 - start })
    }

    public func session(mode: TypingSession.MistakeMode = .strict) -> TypingSession {
      TypingSession(text: text, caret: caret, mistakes: mistakes, mode: mode)
    }
  }

  public struct Today: Codable, Equatable, Sendable {
    public var date: String
    public var activeSeconds: TimeInterval
    public var netCorrectChars: Int
    public var presses: Int
    public var correctPresses: Int
    public var bestWPM: Double
    public var rhythm: Rhythm?

    public init(
      date: String, counters: StatsTracker.Counters = .init(), bestWPM: Double = 0,
      rhythm: Rhythm? = nil
    ) {
      self.date = date
      activeSeconds = counters.activeSeconds
      netCorrectChars = counters.netCorrectChars
      presses = counters.presses
      correctPresses = counters.correctPresses
      self.bestWPM = bestWPM
      self.rhythm = rhythm
    }

    public var counters: StatsTracker.Counters {
      .init(
        netCorrectChars: netCorrectChars, presses: presses, correctPresses: correctPresses,
        activeSeconds: activeSeconds)
    }
  }

  public struct Run: Codable, Equatable, Sendable {
    public var mode: StatsTracker.Mode
    public var source: ContentProvider.Source
    public var startedAt: Date
    public var activeSeconds: TimeInterval
    public var wpm: Double
    public var accuracy: Double
    public var chars: Int

    public init(
      mode: StatsTracker.Mode, source: ContentProvider.Source, startedAt: Date,
      activeSeconds: TimeInterval, wpm: Double, accuracy: Double, chars: Int
    ) {
      self.mode = mode
      self.source = source
      self.startedAt = startedAt
      self.activeSeconds = activeSeconds
      self.wpm = wpm
      self.accuracy = accuracy
      self.chars = chars
    }
  }

  public struct PanelOffset: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
      self.x = x
      self.y = y
    }
  }

  public struct State: Codable, Equatable, Sendable {
    public var version = Store.currentVersion
    public var resume: [String: Resume] = [:]
    public var today: Today
    public var runs: [Run] = []
    public var keys: [String: KeyStats.Entry] = [:]
    public var pairs: [String: KeyStats.Entry] = [:]
    public var panelOffset = PanelOffset()
    public var hintsOn = false
    public var seenIntro = false
    public var lastSprintLength = 30
    public var codePack: CodePack?
    public var bestSprintWPM: [Int: Double]?

    public init(date: String) {
      today = Today(date: date)
    }

    public var keyStats: KeyStats {
      KeyStats(
        keys: Dictionary(
          uniqueKeysWithValues: keys.compactMap { key, value in
            key.count == 1 ? (key.first!, value) : nil
          }), pairs: pairs)
    }

    public mutating func capture(_ keyStats: KeyStats) {
      keys = Dictionary(uniqueKeysWithValues: keyStats.keys.map { (String($0.key), $0.value) })
      pairs = keyStats.pairs
    }

  }

  public struct LoadResult {
    public let state: State
    /// Includes read/decode failures and any failure to quarantine the file.
    public let errors: [any Error]
  }

  public enum Failure: Error {
    case newerVersion
  }

  public let directory: URL
  private let currentDate: () -> Date
  private let calendar: Calendar

  public init(directory: URL, currentDate: @escaping () -> Date, calendar: Calendar = .current) {
    self.directory = directory
    self.currentDate = currentDate
    self.calendar = calendar
  }

  public var today: String {
    let parts = calendar.dateComponents([.year, .month, .day], from: currentDate())
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }

  public func load() -> LoadResult {
    let fresh = State(date: today)
    let file = directory.appendingPathComponent("state.json")
    let data: Data
    do {
      data = try Data(contentsOf: file)
    } catch {
      let missing = (error as NSError).code == NSFileReadNoSuchFileError
      return LoadResult(state: fresh, errors: missing ? [] : [error])
    }
    do {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .millisecondsSince1970
      var state = try decoder.decode(State.self, from: data)
      guard state.version <= Self.currentVersion else { throw Failure.newerVersion }
      state.runs = Array(state.runs.sorted { $0.startedAt > $1.startedAt }.prefix(20))
      if state.today.date != fresh.today.date { state.today = fresh.today }
      return LoadResult(state: state, errors: [])
    } catch {
      var errors: [any Error] = [error]
      // POSIX rename replaces an existing quarantine atomically, without deleting it first.
      let quarantine = directory.appendingPathComponent("state.corrupt.json")
      let result = file.withUnsafeFileSystemRepresentation { source in
        quarantine.withUnsafeFileSystemRepresentation { destination in
          rename(source!, destination!)
        }
      }
      if result != 0 {
        errors.append(NSError(domain: NSPOSIXErrorDomain, code: Int(errno)))
      }
      return LoadResult(state: fresh, errors: errors)
    }
  }

  public func save(_ state: State) throws {
    var saved = state
    saved.runs = Array(saved.runs.sorted { $0.startedAt > $1.startedAt }.prefix(20))
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(saved)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: directory.appendingPathComponent("state.json"), options: .atomic)
  }
}
