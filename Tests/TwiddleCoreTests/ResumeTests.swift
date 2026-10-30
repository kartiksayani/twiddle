import Testing
import TwiddleCore

struct ResumeTests {
  @Test func trimmingCurrentHardLineRebasesCaretAndMarks() {
    let session = TypingSession(text: "old line\na cat\nnext", caret: 13, mistakes: [0, 9, 12, 14])
    let point = Store.Resume(session: session)
    #expect(point.text == "a cat\nnext")
    #expect(point.caret == 4)
    #expect(point.mistakes == [0, 3, 5])
    var restored = point.session()
    #expect(restored.caret == 4)
    #expect(restored.mistakes == [0, 3, 5])
    restored.resumeAtWordStart()
    #expect(restored.caret == 2)
    #expect(restored.mistakes == [0])
    restored.setMode(.forgiving)
    #expect(restored.handle(.backspace).netCorrectChars == -1)
  }

  @Test func trimmingCurrentWrappedLineUsesTextLayoutOffsets() throws {
    let prefix = String(repeating: "word ", count: 10)
    let text = prefix + "tail end"
    let lines = TextLayout.layout(text)
    let current = try #require(lines.last)
    let session = TypingSession(text: text, caret: 53, mistakes: [0, 51, 55])
    let point = Store.Resume(session: session)
    #expect(point.text == String(text.dropFirst(current.lowerBound)))
    #expect(point.caret == 53 - current.lowerBound)
    #expect(point.mistakes == [51 - current.lowerBound, 55 - current.lowerBound])
  }

  @Test func trimmingAtStartOfLineDropsThePreviousLine() {
    let point = Store.Resume(session: TypingSession(text: "old\nnew", caret: 4, mistakes: [0, 4]))
    #expect(point.text == "new")
    #expect(point.caret == 0)
    #expect(point.mistakes == [0])
  }

  @Test func emptyAndEndOfTextResumePointsAreSafe() {
    let empty = Store.Resume(session: TypingSession(text: ""))
    #expect(empty.text.isEmpty)
    #expect(empty.caret == 0)
    let end = Store.Resume(session: TypingSession(text: "a\nb", caret: 3, mistakes: [0, 2]))
    #expect(end.text == "b")
    #expect(end.caret == 1)
    #expect(end.mistakes == [0])
  }
}
