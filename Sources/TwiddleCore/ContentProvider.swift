public struct ContentProvider {
  public enum Source: String, Codable, CaseIterable, Sendable {
    case words, code, prose, weakKeys, symbols

    public var label: String {
      switch self {
      case .words: "Words"
      case .code: "Code"
      case .prose: "Prose"
      case .weakKeys: "Weak keys"
      case .symbols: "Symbols"
      }
    }
  }

  public struct Content: Equatable, Sendable {
    public let text: String
    public let fellBack: Bool
    public var note: String? { fellBack ? ContentProvider.insufficientDataNote : nil }
  }

  static let insufficientDataNote = "Not enough data yet"
  static let words = lines(PackageResources.words_txt)
  private static let packs: [CodePack: [String]] = [
    .go: parseSnippets(PackageResources.code_go_txt),
    .python: parseSnippets(PackageResources.code_python_txt),
    .typescript: parseSnippets(PackageResources.code_typescript_txt),
    .sql: parseSnippets(PackageResources.code_sql_txt),
    .shell: parseSnippets(PackageResources.code_shell_txt),
  ]
  static let code = CodePack.allCases.flatMap { packs[$0, default: []] }
  static let symbols = lines(PackageResources.symbols_txt)
  static let prose = lines(PackageResources.prose_txt)
  static let drills = lines(PackageResources.drills_txt)

  public init() {}

  static func snippets(for pack: CodePack) -> [String] {
    pack == .all ? code : packs[pack, default: []]
  }

  private static func parseSnippets(_ bytes: [UInt8]) -> [String] {
    String(decoding: bytes, as: UTF8.self).dropLast().split(separator: "\n\n").map(String.init)
  }

  public func content<R: RandomNumberGenerator>(
    for source: Source, keyStats: KeyStats = KeyStats(), codePack: CodePack = .all,
    using random: inout R
  ) -> Content {
    let weakKeys = Set(keyStats.weakestKeys.map(\.key))
    let slowestPairs = keyStats.slowestPairs.map(\.letters)
    let rank = { Self.ranked($0, for: weakKeys, pairs: slowestPairs) }
    let fellBack = source == .weakKeys && weakKeys.count < 5
    let source = fellBack ? .words : source
    let candidates: [String]
    let separator: String
    switch source {
    case .words:
      candidates = Self.words
      separator = " "
    case .code:
      candidates = Self.snippets(for: codePack)
      separator = "\n"
    case .symbols:
      candidates = Self.symbols
      separator = "\n"
    case .prose:
      candidates = Self.prose.map { String($0.split(separator: "|", maxSplits: 3)[3]) }
      separator = " "
    case .weakKeys:
      candidates = Array(rank(Self.words).prefix(100))
      separator = " "
    }
    let drills = source == .weakKeys ? Array(rank(Self.drills).prefix(5)) : []
    var text = ""
    var picks = 0
    while text.count < 600 {
      let pool = !drills.isEmpty && picks % 5 == 4 ? drills : candidates
      text += pool[Int.random(in: pool.indices, using: &random)] + separator
      picks += 1
    }
    return Content(text: text, fellBack: fellBack)
  }

  private static func lines(_ bytes: [UInt8]) -> [String] {
    String(decoding: bytes, as: UTF8.self).split(separator: "\n").map(String.init)
  }

  static func ranked(_ items: [String], for keys: Set<Character>, pairs: [String]) -> [String] {
    let scored: [(text: String, score: Int)] = items.map { item in
      let letters = Array(item)
      let pairCount = zip(letters, letters.dropFirst()).filter {
        pairs.contains(String([$0.0, $0.1]))
      }.count
      let score = item.filter { keys.contains($0) }.count + 2 * pairCount
      return (item, score)
    }
    let sorted = scored.sorted { left, right in
      left.score == right.score ? left.text < right.text : left.score > right.score
    }
    return sorted.map(\.text)
  }
}
