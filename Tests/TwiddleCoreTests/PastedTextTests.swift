import Testing

@testable import TwiddleCore

struct PastedTextTests {
  private static let prefix = "Here is practice text "

  @Test(arguments: [
    ("curly quotes", "‘hello’ “world”", "'hello' \"world\""),
    ("dashes", "one–two—three", "one-two-three"),
    ("tabs", "one\ttwo", "one    two"),
    ("CRLF", "one\r\ntwo\rthree", "one\ntwo\nthree"),
    ("blank lines", "one\n\n   \n\n two", "one\n two"),
    ("trailing spaces", "one   \ntwo   ", "one\ntwo"),
    ("emoji", "one🐈👩🏽‍💻two", "onetwo"),
    ("accents", "café naïve voilà", "caf nave voil"),
    (
      "45 character token", String(repeating: "a", count: 45),
      String(repeating: "a", count: 44) + " a"
    ),
    (
      "200 character URL", "https://example.com/" + String(repeating: "x", count: 180),
      "https://example.com/" + String(repeating: "x", count: 24) + " "
        + Array(repeating: String(repeating: "x", count: 44), count: 3).joined(separator: " ")
        + " " + String(repeating: "x", count: 24)
    ),
  ])
  func normalization(row: (String, String, String)) throws {
    let value = try #require(PastedText(Self.prefix + row.1))
    #expect(value.text == Self.prefix + row.2, Comment(rawValue: row.0))
    expectCorpus(value.text)
    #expect(value.text.split(whereSeparator: { $0.isWhitespace }).allSatisfy { $0.count <= 44 })
    #expect(TextLayout.layout(value.text).allSatisfy { $0.count <= 45 })
  }

  @Test func leadingTabsPreserveIndentation() throws {
    let value = try #require(PastedText("\tfirst line for practice\n\tsecond line"))
    #expect(value.text == "    first line for practice\n    second line")
  }

  @Test func onlyWhitespaceIsUnusable() {
    #expect(PastedText(" \t\n\r\n   \t ") == nil)
    #expect(PastedText(String(repeating: "🐈", count: 30)) == nil)
    #expect(PastedText("\u{0}\u{7}\u{1B}\u{7F}") == nil)
  }

  @Test(arguments: [19, 20])
  func minimumAppliesAfterNormalizing(count: Int) {
    let value = PastedText("🐈“" + String(repeating: "a", count: count - 2) + "”🐈")
    #expect((value != nil) == (count == 20))
    #expect(value?.text.count == (count == 20 ? 20 : nil))
  }

  @Test(arguments: [5_000, 5_001])
  func capAppliesToInputBeforeNormalizing(count: Int) throws {
    let input = String(repeating: "a ", count: 2_500) + (count == 5_001 ? "Z" : "")
    let value = try #require(PastedText(input))
    #expect(value.text == String(input.prefix(4_999)))
    #expect(!value.text.contains("Z"))
    #expect(PastedText(String(repeating: "🐈", count: 5_000) + Self.prefix) == nil)
    expectCorpus(value.text)
  }

  @Test func everyPrintableASCIICharacterAndNewlineSurvives() throws {
    let ascii = String((33...126).map { Character(UnicodeScalar($0)!) })
    let value = try #require(PastedText(ascii + "\nnext line"))
    #expect(value.text.filter { !$0.isWhitespace } == ascii + "nextline")
    expectCorpus(value.text)
  }

  private func expectCorpus(_ text: String) {
    #expect(text.unicodeScalars.allSatisfy { $0 == "\n" || (32...126).contains($0.value) })
    #expect(text.allSatisfy { FingerMap.resolve($0) != nil })
  }
}
