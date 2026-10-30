public struct ContentProvider {
  public enum Source: String, Codable, CaseIterable, Sendable {
    case words, code, prose, weakKeys

    public var label: String {
      switch self {
      case .words: "Words"
      case .code: "Code"
      case .prose: "Prose"
      case .weakKeys: "Weak keys"
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
  static let code = String(decoding: PackageResources.code_txt, as: UTF8.self)
    .dropLast().split(separator: "\n\n").map(String.init)
  static let prose = lines(PackageResources.prose_txt)
  static let drills = lines(PackageResources.drills_txt)

  public init() {}

  public func content<R: RandomNumberGenerator>(
    for source: Source, keyStats: KeyStats = KeyStats(), using random: inout R
  ) -> Content {
    let weakKeys = Set(keyStats.weakestKeys.map(\.key))
    let fellBack = source == .weakKeys && weakKeys.count < 5
    let source = fellBack ? .words : source
    let candidates: [String]
    let separator: String
    switch source {
    case .words:
      candidates = Self.words
      separator = " "
    case .code:
      candidates = Self.code
      separator = "\n"
    case .prose:
      candidates = Self.prose.map { String($0.split(separator: "|", maxSplits: 3)[3]) }
      separator = " "
    case .weakKeys:
      candidates = Array(Self.ranked(Self.words, for: weakKeys).prefix(100))
      separator = " "
    }
    let drills = source == .weakKeys ? Array(Self.ranked(Self.drills, for: weakKeys).prefix(5)) : []
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

  private static func ranked(_ items: [String], for keys: Set<Character>) -> [String] {
    let scored: [(text: String, score: Int)] = items.map { item in
      let score = item.filter { keys.contains($0) }.count
      return (item, score)
    }
    let sorted = scored.sorted { left, right in
      left.score == right.score ? left.text < right.text : left.score > right.score
    }
    return sorted.map(\.text)
  }
}
