import Testing
import TwiddleCore

struct TypingSessionTests {
  @Test(arguments: TypingSession.MistakeMode.allCases)
  func correctKeyMidWord(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "cat", mode: mode)
    session.handle(.character("c"))
    let change = session.handle(.character("a"))
    #expect(session.caret == 2)
    #expect(session.pending == nil)
    #expect(change.isCorrect)
    #expect(change.netCorrectChars == 1)
    #expect(session.mistakes.isEmpty)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func wrongKey(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "cat", mode: mode)
    let change = session.handle(.character("x"))
    #expect(session.caret == (mode == .strict ? 0 : 1))
    #expect(session.pending == (mode == .strict ? "x" : nil))
    #expect(session.mistakes == [0])
    #expect(change.isPress)
    #expect(!change.isCorrect)
    #expect(change.expected == "c")
    #expect(change.typed == "x")
    #expect(change.netCorrectChars == 0)
  }

  @Test func secondWrongKeyReplacesPendingAndCountsAnotherPress() {
    var session = TypingSession(text: "cat")
    var tracker = StatsTracker()
    tracker.record(session.handle(.character("x")), at: 0)
    tracker.record(session.handle(.character("y")), at: 0.2)
    #expect(session.caret == 0)
    #expect(session.pending == "y")
    #expect(session.mistakes == [0])
    #expect(tracker.today.presses == 2)
    #expect(tracker.today.correctPresses == 0)
  }

  @Test func correctAfterWrongKeepsFixedMark() {
    var session = TypingSession(text: "cat")
    session.handle(.character("x"))
    let change = session.handle(.character("c"))
    #expect(session.caret == 1)
    #expect(session.pending == nil)
    #expect(session.mistakes == [0])
    #expect(change.isCorrect)
    #expect(session.netCorrectChars == 1)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func backspaceAtZero(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "cat", mode: mode)
    let change = session.handle(.backspace)
    #expect(session.caret == 0)
    #expect(session.pending == nil)
    #expect(session.mistakes.isEmpty)
    #expect(!change.isPress)
    #expect(change.netCorrectChars == 0)
  }

  @Test func strictBackspaceDoesNotMoveThroughCorrectText() {
    var session = TypingSession(text: "cat")
    session.handle(.character("c"))
    let change = session.handle(.backspace)
    #expect(session.caret == 1)
    #expect(session.netCorrectChars == 1)
    #expect(change.netCorrectChars == 0)
  }

  @Test func strictBackspaceOnlyClearsPending() {
    var session = TypingSession(text: "cat")
    session.handle(.character("x"))
    session.handle(.backspace)
    #expect(session.pending == nil)
    #expect(session.caret == 0)
    #expect(session.mistakes == [0])
  }

  @Test func forgivingBackspaceCorrectCharReducesNetOnly() {
    var session = TypingSession(text: "cat", mode: .forgiving)
    var tracker = StatsTracker()
    tracker.record(session.handle(.character("c")), at: 0)
    let change = session.handle(.backspace)
    tracker.record(change, at: 0.1)
    #expect(session.caret == 0)
    #expect(session.netCorrectChars == 0)
    #expect(change.netCorrectChars == -1)
    #expect(tracker.today.netCorrectChars == 0)
    #expect(tracker.today.presses == 1)
    #expect(tracker.today.correctPresses == 1)
  }

  @Test func forgivingBackspaceWrongCharClearsMarkWithoutReducingNet() {
    var session = TypingSession(text: "cat", mode: .forgiving)
    session.handle(.character("x"))
    let change = session.handle(.backspace)
    #expect(session.caret == 0)
    #expect(session.mistakes.isEmpty)
    #expect(session.netCorrectChars == 0)
    #expect(change.netCorrectChars == 0)
    #expect(!change.isPress)
  }

  @Test func forgivingDeleteWordMidWordClearsOnlyRemovedMarks() {
    var session = TypingSession(text: "a cat", mode: .forgiving)
    for character: Character in ["x", " ", "c", "x"] {
      session.handle(.character(character))
    }
    let change = session.handle(.deleteWord)
    #expect(session.caret == 2)
    #expect(session.mistakes == [0])
    #expect(session.netCorrectChars == 1)
    #expect(change.netCorrectChars == -1)
  }

  @Test func forgivingDeleteWordAtWordStartRemovesPreviousWordAndWhitespace() {
    var session = TypingSession(text: "one  two", mode: .forgiving)
    for character in "one  " { session.handle(.character(character)) }
    let change = session.handle(.deleteWord)
    #expect(session.caret == 0)
    #expect(session.netCorrectChars == 0)
    #expect(change.netCorrectChars == -5)
    #expect(!change.isPress)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func deleteWordAtZeroIsNoOp(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "cat", mode: mode)
    let change = session.handle(.deleteWord)
    #expect(session.caret == 0)
    #expect(change.netCorrectChars == 0)
    #expect(!change.isPress)
  }

  @Test func strictDeleteWordOnlyClearsPending() {
    var session = TypingSession(text: "cat")
    session.handle(.character("c"))
    session.handle(.character("x"))
    session.handle(.deleteWord)
    #expect(session.caret == 1)
    #expect(session.pending == nil)
    #expect(session.mistakes == [1])
    #expect(session.netCorrectChars == 1)
    session.handle(.deleteWord)
    #expect(session.caret == 1)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func returnSkipsLeadingSpacesButCreditsOnlyThePress(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "\n   a", mode: mode)
    let change = session.handle(.character("\n"))
    #expect(session.caret == 4)
    #expect(session.expected == "a")
    #expect(session.netCorrectChars == 1)
    #expect(change.isCorrect)
    #expect(change.netCorrectChars == 1)
  }

  @Test func backspaceOverSkippedIndentDoesNotRemoveCredit() {
    var session = TypingSession(text: "\n  a", mode: .forgiving)
    session.handle(.character("\n"))
    #expect(session.handle(.backspace).netCorrectChars == 0)
    #expect(session.caret == 2)
    #expect(session.netCorrectChars == 1)
    #expect(session.handle(.deleteWord).netCorrectChars == -1)
    #expect(session.caret == 0)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func returnElsewhereIsIgnored(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "cat", mode: mode)
    #expect(!session.handle(.character("\n")).isPress)
    #expect(!session.handle(.character("\r")).isPress)
    #expect(session.caret == 0)
    #expect(session.pending == nil)
    #expect(session.mistakes.isEmpty)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func tabIsIgnored(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "cat", mode: mode)
    #expect(!session.handle(.character("\t")).isPress)
    #expect(session.caret == 0)
    #expect(session.mistakes.isEmpty)
  }

  @Test func wrongKeyAtSpaceExposesDisplayGlyphs() {
    var session = TypingSession(text: " ")
    session.handle(.character("x"))
    #expect(session.caret == 0)
    #expect(session.pending == "x")
    #expect(session.expectedGlyph == "·")
    #expect(session.pendingKeyTag == "x")
    #expect(session.mistakes == [0])
  }

  @Test func pendingSpaceHasVisibleKeyTag() {
    var session = TypingSession(text: "a")
    session.handle(.character(" "))
    #expect(session.pendingKeyTag == "␣")
    #expect(session.expectedGlyph == "a")
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func endOfTextIgnoresFurtherCharacters(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: "a", mode: mode)
    session.handle(.character("a"))
    #expect(!session.handle(.character("x")).isPress)
    #expect(session.caret == 1)
    #expect(session.expected == nil)
    #expect(session.expectedGlyph == nil)
    #expect(session.netCorrectChars == 1)
    #expect(session.mistakes.isEmpty)
  }

  @Test func emptyTextIsSafe() {
    var session = TypingSession(text: "")
    #expect(session.expected == nil)
    #expect(!session.handle(.character("x")).isPress)
    #expect(!session.handle(.backspace).isPress)
    #expect(session.needsExtension)
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func extensionPreservesCaretPendingAndMarks(mode: TypingSession.MistakeMode) {
    var session = TypingSession(text: String(repeating: "a", count: 300), mode: mode)
    #expect(!session.needsExtension)
    session.handle(.character("a"))
    #expect(session.needsExtension)
    session.handle(.character("x"))
    let caret = session.caret
    let pending = session.pending
    session.append(" more")
    #expect(session.text == String(repeating: "a", count: 300) + " more")
    #expect(session.caret == caret)
    #expect(session.pending == pending)
    #expect(session.mistakes == [1])
    #expect(session.netCorrectChars == 1)
    #expect(!session.needsExtension)
  }

  @Test func appendingAtEndAllowsTypingAgain() {
    var session = TypingSession(text: "a")
    session.handle(.character("a"))
    session.append("b")
    #expect(session.expected == "b")
    #expect(session.handle(.character("b")).isCorrect)
    #expect(session.caret == 2)
  }

  @Test func changingModeClearsPendingButPreservesCreditAndMarks() {
    var session = TypingSession(text: "ab")
    session.handle(.character("x"))
    session.handle(.character("a"))
    session.handle(.character("x"))
    session.setMode(.forgiving)
    #expect(session.mode == .forgiving)
    #expect(session.pending == nil)
    #expect(session.mistakes == [0, 1])
    #expect(session.handle(.backspace).netCorrectChars == -1)
    #expect(session.mistakes.isEmpty)
  }
}
