import Testing
import TwiddleCore

struct PanelPresenceTests {
  @Test func hiddenHotkeyShows() {
    var presence = PanelPresence()
    #expect(presence.handle(.hotkey) == .show)
    #expect(presence.state == .visible)
  }

  @Test(arguments: [PanelPresence.Event.escape, .resignKey, .outsideMouseDown])
  func hiddenDismissalDoesNothing(event: PanelPresence.Event) {
    var presence = PanelPresence()
    #expect(presence.handle(event) == nil)
    #expect(presence.state == .hidden)
  }

  @Test func visibleHotkeyHides() {
    var presence = visiblePresence()
    #expect(presence.handle(.hotkey) == .hide)
    #expect(presence.state == .hidden)
  }

  @Test func visibleEscapeHides() {
    var presence = visiblePresence()
    #expect(presence.handle(.escape) == .hide)
    #expect(presence.state == .hidden)
  }

  @Test func visibleResignKeyHides() {
    var presence = visiblePresence()
    #expect(presence.handle(.resignKey) == .hide)
    #expect(presence.state == .hidden)
  }

  @Test func visibleOutsideMouseDownHides() {
    var presence = visiblePresence()
    #expect(presence.handle(.outsideMouseDown) == .hide)
    #expect(presence.state == .hidden)
  }

  @Test func visibleInsideMouseDownStaysVisible() {
    var presence = visiblePresence()
    #expect(presence.handle(.insideMouseDown) == nil)
    #expect(presence.state == .visible)
  }

  private func visiblePresence() -> PanelPresence {
    var presence = PanelPresence()
    _ = presence.handle(.hotkey)
    return presence
  }
}
