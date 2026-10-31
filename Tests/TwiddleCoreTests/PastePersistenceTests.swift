import Foundation
import Testing
import TwiddleCore

@MainActor
struct PastePersistenceTests {
  enum Path: CaseIterable {
    case resumeSave, flowCache, hide, quit, flowRunEnd, sprintRunEnd
    case sourceSwitch, modeSwitch, dayRollover, panelRelaunch
  }

  @Test(arguments: Path.allCases)
  func pastedSentinelNeverReachesStateFile(path: Path) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    let sentinel = "sentinel" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24)
    f.model.summon()
    f.model.paste(sentinel + " alpha beta gamma delta alpha beta gamma delta")
    #expect(f.model.session.text.contains(sentinel))
    if path == .sprintRunEnd { f.model.handle(.sprint) }
    f.type(60)
    switch path {
    case .resumeSave:
      f.model.setHints(true)
    case .flowCache:
      f.model.handle(.sprint)
      f.model.handle(.source(.symbols))
      f.model.handle(.flow)
      f.model.setPanelOffset(.init(x: 12, y: 8))
    case .hide:
      f.model.hide()
    case .quit:
      f.model.quit()
    case .flowRunEnd:
      f.time += 300
      f.model.tick()
      #expect(f.model.stats.run == nil)
    case .sprintRunEnd:
      f.time = 30
      f.model.tick()
      f.time = 30.6
      f.model.tick()
      #expect(f.model.result?.slowestPair != nil)
    case .sourceSwitch:
      f.model.handle(.source(.prose))
    case .modeSwitch:
      f.model.handle(.sprint)
    case .dayRollover:
      f.date = f.date.addingTimeInterval(86_400)
      f.model.refreshToday()
      f.model.quit()
      #expect(f.model.state.today.presses == 0)
    case .panelRelaunch:
      f.model.hide()
      f.model.summon()
      #expect(f.model.source == .pasted)
      #expect(f.model.session.text.contains(sentinel))
      f.model.handle(.source(.words))
      f.model.hide()
      f.model.summon()
      f.model.quit()
    }
    try expectNoText(f, sentinel: sentinel)
    let saved = f.store.load().state
    #expect(saved.today.presses == (path == .dayRollover ? 0 : 60))
    #expect(
      saved.keys == f.model.stats.keyStats.keys.reduce(into: [:]) { $0[String($1.key)] = $1.value })
    #expect(saved.pairs == f.model.stats.keyStats.pairs)
    #expect(!saved.keys.isEmpty)
    #expect(!saved.pairs.isEmpty)
    if path != .resumeSave {
      #expect(saved.runs.count == 1)
      #expect(saved.runs[0].source == .pasted)
      #expect(saved.runs[0].chars == 60)
    }
  }

  @Test(arguments: ContentProvider.Source.defaultSources)
  func savingAnotherSourceDoesNotSerializeCachedPaste(source: ContentProvider.Source) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    let sentinel = "cache" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    f.model.summon()
    f.model.paste(sentinel + " cached private clipboard text")
    f.model.handle(.source(source))
    f.model.handle(.freshText)
    f.model.setHints(true)
    f.model.quit()
    try expectNoText(f, sentinel: sentinel)
  }

  @Test func stateWithPastedRunLoadsAndKeepsTotals() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    var state = Store.State(date: f.store.today)
    state.runs = [
      .init(
        mode: .flow, source: .pasted, startedAt: f.date, activeSeconds: 10,
        wpm: 60, accuracy: 0.98, chars: 50)
    ]
    try f.store.save(state)
    let loaded = f.store.load()
    #expect(loaded.errors.isEmpty)
    #expect(loaded.state.runs == state.runs)
    f.model.summon()
    #expect(f.model.source == .words)
    #expect(f.model.progress.points.count == 1)
  }

  @Test func storeExcludesPastedResumeOnWriteAndIgnoresItOnLoad() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    let sentinel = "storeSentinelForPrivateClipboardText"
    var state = Store.State(date: f.store.today)
    state.resume["pasted"] = Store.Resume(session: TypingSession(text: sentinel))
    try f.store.save(state)
    try expectNoText(f, sentinel: sentinel)
    // An older or hand-edited file must not restore pasted content either.
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    try encoder.encode(state).write(to: f.directory.appendingPathComponent("state.json"))
    let loaded = f.store.load()
    #expect(loaded.errors.isEmpty)
    #expect(loaded.state.resume["pasted"] == nil)
    f.model.summon()
    f.model.quit()
    try expectNoText(f, sentinel: sentinel)
  }

  @Test func sprintResultKeepsSlowestPairOnlyInMemory() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.paste("alpha beta alpha beta alpha beta alpha beta")
    f.model.handle(.sprint)
    f.type(100)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    #expect(f.model.result?.slowestPair?.count == 2)
    let bytes = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    #expect(bytes.range(of: Data("slowestPair".utf8)) == nil)
    let saved = f.store.load().state
    #expect(saved.keys.keys.allSatisfy { $0.count == 1 })
    #expect(
      saved.pairs.keys.allSatisfy { pair in
        pair.utf8.count == 2 && pair.utf8.allSatisfy { (97...122).contains($0) }
      })
    #expect(saved.runs.first?.source == .pasted)
  }

  private func expectNoText(_ f: PracticeFixture, sentinel: String) throws {
    let bytes = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    #expect(bytes.range(of: Data(sentinel.utf8)) == nil)
    #expect(bytes.range(of: Data("slowestPair".utf8)) == nil)
    let state = f.store.load().state
    #expect(state.resume["pasted"] == nil)
    #expect(state.resume.values.allSatisfy { !$0.text.contains(sentinel) })
    #expect(state.keys.keys.allSatisfy { $0.count == 1 })
    #expect(
      state.pairs.keys.allSatisfy {
        $0.utf8.count == 2 && $0.utf8.allSatisfy { (97...122).contains($0) }
      })
  }
}
