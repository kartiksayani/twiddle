import Testing
import TwiddleCore

struct CommandCapsuleTests {
  @Test func heldCommandShowsAt300Milliseconds() {
    var capsule = CommandCapsule()
    capsule.handle(.commandDown, at: 0)
    capsule.handle(.tick, at: 0.299)
    #expect(!capsule.isVisible)
    capsule.handle(.commandDown, at: 0.299)
    capsule.handle(.tick, at: 0.3)
    #expect(capsule.isVisible)
  }

  @Test func quickReleaseNeverShows() {
    var capsule = CommandCapsule()
    capsule.handle(.commandDown, at: 0)
    capsule.handle(.commandUp, at: 0.2)
    capsule.handle(.tick, at: 1)
    #expect(!capsule.isVisible)
  }

  @Test func quickChordNeverShowsUntilNextHold() {
    var capsule = CommandCapsule()
    capsule.handle(.commandDown, at: 0)
    capsule.handle(.chord, at: 0.1)
    capsule.handle(.commandDown, at: 0.2)
    capsule.handle(.tick, at: 1)
    #expect(!capsule.isVisible)
    capsule.handle(.commandUp, at: 1)
    capsule.handle(.commandDown, at: 2)
    capsule.handle(.tick, at: 2.31)
    #expect(capsule.isVisible)
    capsule.handle(.chord, at: 2.4)
    #expect(capsule.isVisible)
  }

  @Test func releaseHides() {
    var capsule = CommandCapsule()
    capsule.handle(.commandDown, at: 0)
    capsule.handle(.tick, at: 0.3)
    capsule.handle(.commandUp, at: 0.4)
    #expect(!capsule.isVisible)
  }

  @Test(arguments: [false, true]) func hideOrLostKeyStatusDismisses(whileWaiting: Bool) {
    var capsule = CommandCapsule()
    capsule.handle(.commandDown, at: 0)
    if !whileWaiting { capsule.handle(.tick, at: 0.3) }
    capsule.handle(.dismiss, at: 0.4)
    capsule.handle(.tick, at: 1)
    #expect(!capsule.isVisible)
  }
}
