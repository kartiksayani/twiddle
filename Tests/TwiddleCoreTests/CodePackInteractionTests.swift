import Foundation
import Testing

@testable import TwiddleCore

@MainActor
struct CodePackInteractionTests {
  @Test(arguments: [false, true])
  func flowTyping(onCode: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    f.model.summon()
    if onCode { f.model.handle(.source(.code)) }
    f.type(50)
    f.model.handle(.character("!"))
    let old = f.model.session
    let today = f.model.stats.today
    f.model.handle(.source(.code))
    #expect(f.model.mode == .flow)
    #expect(f.model.view == .text)
    #expect(f.model.stats.run == nil)
    #expect(f.model.stats.today == today)
    #expect(f.model.state.runs.count == 1)
    #expect(f.model.state.runs[0].source == (onCode ? .code : .words))
    if onCode {
      expectCycled(f, old: old)
    } else {
      #expect(f.model.codePack == .python)
      #expect(f.model.sourceLabel == "Code · Python")
      #expect(f.model.session.text == savedCode)
      #expect(f.model.session.caret == 8)
      #expect(f.model.session.mistakes == [0])
    }
  }

  @Test(arguments: [false, true])
  func sprintReady(onCode: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    startSprint(f, onCode: onCode)
    let old = f.model.session
    f.model.handle(.source(.code))
    expectReady(f)
    #expect(f.model.state.runs.isEmpty)
    if onCode { expectCycled(f, old: old) } else { expectSelected(f, old: old) }
  }

  @Test(arguments: [false, true])
  func sprintRunning(onCode: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    startSprint(f, onCode: onCode)
    f.type(10)
    let old = f.model.session
    let today = f.model.stats.today
    f.model.handle(.source(.code))
    expectReady(f)
    #expect(f.model.state.runs.isEmpty)
    #expect(f.model.stats.today == today)
    #expect(!f.model.stats.keyStats.keys.isEmpty)
    if onCode { expectCycled(f, old: old) } else { expectSelected(f, old: old) }
  }

  @Test(arguments: [false, true])
  func sprintResult(onCode: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    startSprint(f, onCode: onCode)
    f.type(10)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    #expect(f.model.sprintState == .result)
    let old = f.model.session
    let runs = f.model.state.runs
    f.model.handle(.source(.code))
    expectReady(f)
    #expect(f.model.state.runs == runs)
    #expect(runs.count == 1)
    #expect(runs[0].source == (onCode ? .code : .words))
    if onCode { expectCycled(f, old: old) } else { expectSelected(f, old: old) }
  }

  @Test(arguments: [false, true], [StatsTracker.Mode.flow, .sprint])
  func progress(onCode: Bool, mode: StatsTracker.Mode) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    f.model.summon()
    if onCode { f.model.handle(.source(.code)) }
    if mode == .sprint { f.model.handle(.sprint) }
    f.model.handle(.progress)
    #expect(f.model.view == .progress)
    let old = f.model.session
    f.model.handle(.source(.code))
    #expect(f.model.view == .text)
    #expect(f.model.mode == mode)
    if mode == .sprint { expectReady(f) }
    if onCode {
      expectCycled(f, old: old)
    } else if mode == .sprint {
      expectSelected(f, old: old)
    } else {
      #expect(f.model.codePack == .python)
      #expect(f.model.session.text == savedCode)
      #expect(f.model.session.caret == 8)
    }
  }

  @Test(arguments: [false, true])
  func intro(onCode: Bool) throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    try seed(f.practice)
    f.settings.defaultSource = onCode ? .code : .words
    f.model.launch()
    let state = f.model.state
    let old = f.model.session
    f.model.handle(.source(.code))
    #expect(f.model.view == .intro)
    #expect(f.model.source == (onCode ? .code : .words))
    #expect(f.model.codePack == .python)
    #expect(f.model.session.text == old.text)
    #expect(f.model.session.caret == old.caret)
    #expect(f.model.state == state)
  }

  @Test(arguments: [false, true])
  func lockedSprintChangesSourceWithoutDuplicatingResult(onCode: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    startSprint(f, onCode: onCode)
    f.type(1)
    f.time = 30
    f.model.tick()
    #expect(f.model.sprintState == .locked)
    let old = f.model.session
    f.model.handle(.source(.code))
    expectReady(f)
    #expect(f.model.state.runs.count == 1)
    if onCode { expectCycled(f, old: old) } else { expectSelected(f, old: old) }
    f.time = 31
    f.model.tick()
    #expect(f.model.sprintState == .ready)
    #expect(f.model.state.runs.count == 1)
  }

  @Test func cycleOrderPersistsAndReturningToCodeResumesTheSavedPack() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.source(.code))
    #expect(f.model.codePack == .all)
    #expect(f.model.sourceLabel == "Code")
    let cycle: [CodePack] = [.go, .python, .typescript, .sql, .shell, .all]
    for pack in cycle {
      f.model.handle(.source(.code))
      #expect(f.model.codePack == pack)
      #expect(f.store.load().state.codePack == pack)
      #expect(f.model.sourceLabel == (pack == .all ? "Code" : "Code · \(pack.label)"))
      f.type(7)
      let old = f.model.session
      f.model.handle(.source(.symbols))
      f.model.handle(.source(.code))
      #expect(f.model.codePack == pack)
      #expect(f.model.session.text == old.text)
      #expect(f.model.session.caret == old.caret)
    }
    f.model.handle(.source(.code))
    f.type(7)
    f.model.hide()
    let saved = try #require(f.store.load().state.resume["code"])
    let relaunched = PracticeModel(store: f.store, random: FixedRandom())
    #expect(relaunched.codePack == .go)
    relaunched.summon()
    relaunched.handle(.source(.code))
    #expect(relaunched.codePack == .go)
    #expect(relaunched.session.text == saved.text)
    var expected = saved.session()
    expected.resumeAtWordStart()
    #expect(relaunched.session.caret == expected.caret)
  }

  @Test func symbolsCanBeThePersistedDefaultSource() throws {
    let f = SettingsFixture()
    defer { try! f.clean() }
    f.settings.defaultSource = .symbols
    #expect(Settings(defaults: f.defaults).defaultSource == .symbols)
    f.model.summon()
    #expect(f.model.source == .symbols)
    #expect(f.model.sourceLabel == "Symbols")
    #expect(f.model.session.text.contains("\n"))
    f.model.handle(.character(f.model.session.expected!))
    f.model.hide()
    #expect(f.practice.store.load().state.resume["symbols"] != nil)
  }

  @Test func cyclingInSprintReplacesCachedFlowAndExtensionsUseTheNewPack() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try seed(f)
    startSprint(f, onCode: true)
    f.model.handle(.source(.code))
    let fresh = f.model.session.text
    f.model.handle(.flow)
    #expect(f.model.codePack == .typescript)
    #expect(f.model.session.text == fresh)
    #expect(f.model.session.caret == 0)
    f.type(fresh.count - 299)
    #expect(f.model.session.text.count > fresh.count)
    var remaining = f.model.session.text
    let snippets = ContentProvider.snippets(for: .typescript)
    while !remaining.isEmpty {
      let entry = try #require(snippets.first { remaining.hasPrefix($0 + "\n") })
      remaining.removeFirst(entry.count + 1)
    }
    f.model.hide()
    f.model.summon()
    #expect(f.model.codePack == .typescript)
    #expect(f.model.session.text != savedCode)
  }

  private var savedCode: String { String(repeating: "count = 42\n", count: 80) }

  private func seed(_ f: PracticeFixture) throws {
    var state = Store.State(date: f.store.today)
    state.codePack = .python
    state.resume["code"] = Store.Resume(
      session: TypingSession(text: savedCode, caret: 8, mistakes: [0]))
    try f.store.save(state)
  }

  private func startSprint(_ f: PracticeFixture, onCode: Bool) {
    f.model.summon()
    if onCode { f.model.handle(.source(.code)) }
    f.model.handle(.sprint)
  }

  private func expectReady(_ f: PracticeFixture) {
    #expect(f.model.source == .code)
    #expect(f.model.view == .text)
    #expect(f.model.mode == .sprint)
    #expect(f.model.sprintState == .ready)
    #expect(f.model.sprintLength == 30)
    #expect(f.model.sprintElapsed == 0)
    #expect(f.model.headerCounters == .init())
    #expect(f.model.stats.run == nil)
    #expect(f.model.result == nil)
    #expect(f.model.session.caret == 0)
  }

  private func expectCycled(_ f: PracticeFixture, old: TypingSession) {
    #expect(f.model.codePack == .typescript)
    #expect(f.model.sourceLabel == "Code · TypeScript")
    #expect(f.model.session.text != old.text)
    #expect(f.model.session.caret == 0)
    #expect(f.model.session.pending == nil)
    #expect(f.model.session.mistakes.isEmpty)
    #expect(f.model.resumedWord == nil)
    #expect(f.model.characters == Array(f.model.session.text))
    #expect(f.model.lines == TextLayout.layout(f.model.session.text))
    #expect(f.model.state.resume["code"] == Store.Resume(session: f.model.session))
    #expect(f.store.load().state.resume["code"] == f.model.state.resume["code"])
    #expect(f.store.load().state.codePack == .typescript)
  }

  private func expectSelected(_ f: PracticeFixture, old: TypingSession) {
    #expect(f.model.codePack == .python)
    #expect(f.model.session.text != old.text)
    #expect(f.model.session.text != savedCode)
  }
}
