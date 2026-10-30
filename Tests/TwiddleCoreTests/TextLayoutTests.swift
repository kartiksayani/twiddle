import Testing
import TwiddleCore

struct TextLayoutTests {
  @Test func emptyTextHasNoLines() {
    #expect(TextLayout.layout("").isEmpty)
  }

  @Test func shortLineRetainsSpaces() {
    #expect(TextLayout.layout("one two ") == [0..<8])
  }

  @Test func wrapsAtWordBoundaryAndRetainsTrailingSpace() {
    let text = String(repeating: "a", count: 40) + " " + "word next"
    #expect(TextLayout.layout(text) == [0..<46, 46..<50])
  }

  @Test func fortySixColumnsExcludeTrailingDelimiterAsInPrototype() {
    let text = String(repeating: "a", count: 44) + " b c"
    #expect(TextLayout.layout(text) == [0..<47, 47..<48])
  }

  @Test func oversizedWordIsNeverSplitAsInPrototype() {
    let text = String(repeating: "a", count: 70) + " b"
    #expect(TextLayout.layout(text) == [0..<71, 71..<72])
  }

  @Test func hardBreakIncludesNewlineAndPreservesIndentation() {
    #expect(TextLayout.layout("one\n  two\nthree") == [0..<4, 4..<10, 10..<15])
  }

  @Test func blankLinesAreRetainedWithoutInventingTrailingLine() {
    #expect(TextLayout.layout("\n\na\n") == [0..<1, 1..<2, 2..<4])
  }

  @Test func wrapsIndependentlyOnEachHardLine() {
    let text = String(repeating: "a", count: 40) + " abcdef\nlast"
    #expect(TextLayout.layout(text) == [0..<41, 41..<48, 48..<52])
  }
}
