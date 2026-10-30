import Testing

@testable import TwiddleCore

struct SeededRandom: RandomNumberGenerator {
  var state: UInt64
  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

struct ContentProviderTests {
  @Test func corporaMeetTheGate() throws {
    let corpora = [
      (String(decoding: PackageResources.words_txt, as: UTF8.self), 900...1100, "\n"),
      (String(decoding: PackageResources.code_txt, as: UTF8.self), 54...66, "\n\n"),
      (String(decoding: PackageResources.prose_txt, as: UTF8.self), 36...44, "\n"),
      (String(decoding: PackageResources.drills_txt, as: UTF8.self), 10...40, "\n"),
    ]
    for (text, count, separator) in corpora {
      #expect(text.utf8.allSatisfy { $0 == 10 || (32...126).contains($0) })
      #expect(text.allSatisfy { FingerMap.resolve($0) != nil })
      #expect(!text.contains("\t"))
      #expect(text.hasSuffix("\n"))
      for token in text.split(whereSeparator: \.isWhitespace) {
        #expect(token.count <= 44)
      }
      let entries = text.dropLast().split(separator: separator, omittingEmptySubsequences: false)
      #expect(count.contains(entries.count))
      #expect(Set(entries).count == entries.count)
      #expect(entries.allSatisfy { !$0.isEmpty })
    }
    #expect(ContentProvider.code.filter { $0.contains("\n    ") }.count >= 15)
    #expect(
      ContentProvider.code.contains(
        "git rebase -i HEAD~3 && git push --force-with-lease origin main"))
    #expect(ContentProvider.words.allSatisfy { $0.utf8.allSatisfy { (97...122).contains($0) } })
    for line in ContentProvider.prose {
      let parts = line.split(separator: "|", omittingEmptySubsequences: false)
      #expect(parts.count == 4)
      #expect(!parts[0].isEmpty && !parts[1].isEmpty && !parts[3].isEmpty)
      let year = try #require(Int(parts[2]))
      #expect((1..<1931).contains(year))
    }
  }

  @Test(arguments: ContentProvider.Source.allCases)
  func sourcesProduceExtendableTextWithRepeatableRandomness(source: ContentProvider.Source) {
    var first = SeededRandom(state: 42)
    var second = SeededRandom(state: 42)
    var other = SeededRandom(state: 19)
    let provider = ContentProvider()
    let content = provider.content(for: source, using: &first)
    #expect(content == provider.content(for: source, using: &second))
    #expect(content.text != provider.content(for: source, using: &other).text)
    #expect(content.text.count >= 600)
    #expect(content.text.allSatisfy { FingerMap.resolve($0) != nil })
    #expect(content.fellBack == (source == .weakKeys))
    #expect(content.note == (source == .weakKeys ? "Not enough data yet" : nil))
  }

  @Test(arguments: [0, 1, 4])
  func weakKeysFallsBackToIdenticalWordsUntilFiveAreRanked(count: Int) {
    var random = SeededRandom(state: 3)
    var comparison = SeededRandom(state: 3)
    let content = ContentProvider().content(
      for: .weakKeys, keyStats: rankedStats(count), using: &random)
    let words = ContentProvider().content(for: .words, using: &comparison)
    #expect(content.fellBack)
    #expect(content.text == words.text)
  }

  @Test func weakKeysBiasWordsAndMixInSymbolDrills() {
    var random = SeededRandom(state: 1)
    let content = ContentProvider().content(
      for: .weakKeys, keyStats: rankedStats(5), using: &random)
    #expect(!content.fellBack)
    #expect(content.note == nil)
    #expect(content.text.contains { !$0.isLetter && !$0.isWhitespace })
    let selectedWords = content.text.split(separator: " ").filter { $0.allSatisfy(\.isLetter) }
    let weakKeys = Set("abcde")
    let ranked = ContentProvider.words.sorted {
      let left = $0.filter { weakKeys.contains($0) }.count
      let right = $1.filter { weakKeys.contains($0) }.count
      return left == right ? $0 < $1 : left > right
    }
    let eligible = Set(ranked.prefix(100))
    #expect(selectedWords.count > 20)
    #expect(selectedWords.prefix(4).allSatisfy { eligible.contains(String($0)) })
    #expect(
      selectedWords.filter { eligible.contains(String($0)) }.count * 10 > selectedWords.count * 7)
    #expect(ContentProvider.drills.contains { content.text.contains($0) })
  }

  @Test func proseOnlyServesPassagesAndCodeHasRealNewlines() throws {
    var random = SeededRandom(state: 7)
    let prose = ContentProvider().content(for: .prose, using: &random).text
    #expect(!prose.contains("|"))
    #expect(!prose.contains("1865") && !prose.contains("1895"))
    #expect(!prose.contains("\n"))
    let code = ContentProvider().content(for: .code, using: &random).text
    #expect(code.contains("\n"))
    let passages = ContentProvider.prose.map { String($0.split(separator: "|", maxSplits: 3)[3]) }
    for (text, candidates, separator) in [
      (prose, passages, " "), (code, ContentProvider.code, "\n"),
    ] {
      var remaining = text
      while !remaining.isEmpty {
        let entry = try #require(candidates.first { remaining.hasPrefix($0 + separator) })
        remaining.removeFirst(entry.count + separator.count)
      }
    }
  }

  @Test(arguments: TypingSession.MistakeMode.allCases)
  func typingCodeSnippetSkipsIndentation(mode: TypingSession.MistakeMode) throws {
    let snippet = try #require(ContentProvider.code.first { $0.contains("\n    ") })
    var session = TypingSession(text: snippet, mode: mode)
    var presses = 0
    for (index, line) in snippet.split(separator: "\n").enumerated() {
      let indentation = line.prefix(while: { $0 == " " }).count
      if index > 0 {
        let caret = session.caret
        #expect(session.handle(.character("\n")).isCorrect)
        #expect(session.caret == caret + 1 + indentation)
        presses += 1
      }
      for key in line.dropFirst(indentation) {
        #expect(session.handle(.character(key)).isCorrect)
        presses += 1
      }
    }
    #expect(session.caret == snippet.count)
    #expect(session.netCorrectChars == presses)
    #expect(presses < snippet.count)
    #expect(session.mistakes.isEmpty)
  }

  private func rankedStats(_ count: Int) -> KeyStats {
    var stats = KeyStats()
    for key in "abcde".prefix(count) {
      stats.breakSequence()
      for index in 0...20 { stats.record(enginePress(key), at: Double(index) * 0.25) }
    }
    return stats
  }
}
