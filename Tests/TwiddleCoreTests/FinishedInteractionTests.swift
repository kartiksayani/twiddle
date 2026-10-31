import Foundation
import Testing
import TwiddleCore

@MainActor
struct FinishedInteractionTests {
  private let done = URL(string: "twiddle://done")!

  @Test(arguments: [false, true])
  func hiddenIncludingSettingsIgnoresDone(afterHidingForSettings: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed()
    if afterHidingForSettings {
      f.model.summon()
      f.type(2)
      f.model.hide()
    }
    let state = f.model.state
    let saved = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    f.model.handle(done)
    #expect(!f.model.isVisible)
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == nil)
    #expect(f.model.state == state)
    #expect(try Data(contentsOf: f.directory.appendingPathComponent("state.json")) == saved)
    f.time = 1
    f.model.summon()
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == nil)
  }

  @Test(arguments: [false, true])
  func textFlowOrSprintReadyKeepsTyping(sprintReady: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    if sprintReady { f.model.handle(.sprint) }
    f.time = 2
    expectSignalChangesOnlyPill(f)
    let caret = f.model.session.caret
    let presses = f.model.stats.today.presses
    f.type(1)
    #expect(f.model.session.caret == caret + 1)
    #expect(f.model.stats.today.presses == presses + 1)
    #expect(f.model.showsFinished)
    #expect(f.model.view == .text)
    if sprintReady { #expect(f.model.sprintState == .running) }
    expectExpiryAndHide(f, since: 2)
  }

  @Test func runningSprintKeepsItsRunAndClock() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    f.type(2)
    f.time = 5
    f.model.tick()
    let run = try #require(f.model.stats.run)
    expectSignalChangesOnlyPill(f)
    f.type(1)
    #expect(f.model.sprintState == .running)
    #expect(f.model.session.caret == 3)
    #expect(f.model.stats.run?.startedAt == run.startedAt)
    #expect(f.model.stats.run?.counters.presses == run.counters.presses + 1)
    #expect(f.model.showsFinished)
    f.time = 10
    f.model.tick()
    #expect(f.model.sprintElapsed == 10)
    #expect(f.model.sprintRemaining == 20)
    expectExpiryAndHide(f, since: 5)
    #expect(f.model.state.runs.isEmpty)
  }

  @Test func sprintResultKeepsResultAndReturnBehavior() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(.sprint)
    f.type(2)
    f.time = 30
    f.model.tick()
    f.time = 30.6
    f.model.tick()
    let result = try #require(f.model.result)
    expectSignalChangesOnlyPill(f)
    let caret = f.model.session.caret
    f.model.handle(.character("x"))
    #expect(f.model.sprintState == .result)
    #expect(f.model.result?.counters == result.counters)
    #expect(f.model.session.caret == caret)
    #expect(f.model.showsFinished)
    expectExpiryAndHide(f, since: 30.6)
    f.model.summon()
    f.type(1)
    f.time = 80
    f.model.tick()
    f.time = 80.6
    f.model.tick()
    f.model.handle(done)
    f.model.handle(.character("\n"))
    #expect(f.model.sprintState == .ready)
    #expect(f.model.showsFinished)
  }

  @Test(arguments: [false, true])
  func progressOrIntroKeepsViewAndTypingBehavior(intro: Bool) throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    if intro {
      f.model.launch()
    } else {
      f.model.summon()
      f.model.handle(.progress)
    }
    let view = f.model.view
    expectSignalChangesOnlyPill(f)
    #expect(f.model.view == view)
    f.model.handle(.character(f.model.session.expected!))
    #expect(f.model.view == .text)
    #expect(f.model.session.caret == 1)
    #expect(f.model.showsFinished)
    #expect(f.model.seenIntro == intro)
    expectExpiryAndHide(f, since: 0)
  }

  @Test func alreadyShowingRestartsTenSeconds() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(done)
    f.time = 9
    f.model.handle(done)
    f.type(1)
    #expect(f.model.session.caret == 1)
    #expect(f.model.showsFinished)
    f.time = 10
    f.model.tick()
    #expect(f.model.showsFinished)
    expectExpiryAndHide(f, since: 9)
  }

  @Test func heldCapsuleKeepsSlotWhileTimerRuns() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handleCapsule(.commandDown)
    f.time = 0.3
    f.model.tick()
    #expect(f.model.capsuleContent == .commands)
    f.model.handle(done)
    #expect(f.model.showsFinished)
    #expect(f.model.capsuleContent == .commands)
    f.time = 5
    f.model.handleCapsule(.commandUp)
    #expect(f.model.capsuleContent == .finished)
    f.model.handleCapsule(.commandDown)
    f.time = 6
    f.model.tick()
    #expect(f.model.capsuleContent == .commands)
    f.time = 10.299
    f.model.tick()
    #expect(f.model.showsFinished)
    f.time = 10.3
    f.model.tick()
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == .commands)
    f.model.handleCapsule(.commandUp)
    #expect(f.model.capsuleContent == nil)
    f.model.handleCapsule(.commandDown)
    f.time = 11
    f.model.tick()
    f.model.handle(done)
    f.model.hide()
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == nil)
    f.model.summon()
    f.time = 12
    f.model.tick()
    #expect(f.model.capsuleContent == nil)
  }

  @Test func rejectedURLDoesNotSetOrExtendPill() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.summon()
    f.model.handle(URL(string: "twiddle://done?private=text")!)
    #expect(!f.model.showsFinished)
    f.model.handle(done)
    f.time = 9
    f.model.handle(URL(string: "twiddle://done#private")!)
    f.time = 10
    f.model.tick()
    #expect(!f.model.showsFinished)
  }

  @Test func quitClearsPillAndItIsNeverPersisted() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    try f.seed()
    f.model.summon()
    let saved = try Data(contentsOf: f.directory.appendingPathComponent("state.json"))
    f.model.handle(done)
    #expect(try Data(contentsOf: f.directory.appendingPathComponent("state.json")) == saved)
    let state = f.model.state
    f.model.quit()
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == nil)
    #expect(f.store.load().state == state)
    let relaunched = PracticeModel(store: f.store, random: FixedRandom(), now: { f.time })
    relaunched.summon()
    #expect(!relaunched.showsFinished)
  }

  @Test func hiddenCapsuleEventsDoNotAppearOnSummon() throws {
    let f = PracticeFixture()
    defer { try! f.clean() }
    f.model.handleCapsule(.commandDown)
    f.time = 1
    f.model.summon()
    f.model.tick()
    #expect(f.model.capsuleContent == nil)
  }

  private func expectSignalChangesOnlyPill(_ f: PracticeFixture) {
    let session = f.model.session
    let today = f.model.stats.today
    let run = f.model.stats.run
    let view = f.model.view
    let sprintState = f.model.sprintState
    let elapsed = f.model.sprintElapsed
    let state = f.model.state
    f.model.handle(done)
    #expect(f.model.showsFinished)
    #expect(f.model.capsuleContent == .finished)
    #expect(f.model.isVisible)
    #expect(f.model.session.text == session.text)
    #expect(f.model.session.caret == session.caret)
    #expect(f.model.session.pending == session.pending)
    #expect(f.model.session.mistakes == session.mistakes)
    #expect(f.model.stats.today == today)
    #expect(f.model.stats.run?.startedAt == run?.startedAt)
    #expect(f.model.stats.run?.counters == run?.counters)
    #expect(f.model.view == view)
    #expect(f.model.sprintState == sprintState)
    #expect(f.model.sprintElapsed == elapsed)
    #expect(f.model.state == state)
  }

  private func expectExpiryAndHide(_ f: PracticeFixture, since start: TimeInterval) {
    f.time = start + 9.999
    f.model.tick()
    #expect(f.model.showsFinished)
    f.time = start + 10
    f.model.tick()
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == nil)
    #expect(f.model.isVisible)
    f.model.handle(done)
    f.model.hide()
    #expect(!f.model.showsFinished)
    #expect(f.model.capsuleContent == nil)
    f.model.summon()
    #expect(!f.model.showsFinished)
  }
}
