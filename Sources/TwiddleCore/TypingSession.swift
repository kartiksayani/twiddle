public struct TypingSession {
  public enum MistakeMode: Sendable, CaseIterable {
    case strict
    case forgiving
  }

  public enum Input {
    case character(Character)
    case backspace
    case deleteWord
  }

  /// A text press carries both characters; deletions carry only the net correction.
  public struct Change: Equatable, Sendable {
    public let expected: Character?
    public let typed: Character?
    public let netCorrectChars: Int

    public var isPress: Bool { typed != nil }
    public var isCorrect: Bool { isPress && typed == expected }

    static let ignored = Change(expected: nil, typed: nil, netCorrectChars: 0)
  }

  public private(set) var text: String
  public private(set) var caret = 0
  public private(set) var pending: Character?
  public private(set) var mistakes: Set<Int> = []
  public private(set) var mode: MistakeMode
  private var characters: [Character]
  private var creditedOffsets: Set<Int> = []

  public init(text: String, mode: MistakeMode = .strict) {
    self.text = text
    self.characters = Array(text)
    self.mode = mode
  }

  public init(text: String, caret: Int, mistakes: Set<Int>, mode: MistakeMode = .strict) {
    self.init(text: text, mode: mode)
    self.caret = min(max(0, caret), characters.count)
    self.mistakes = mistakes.filter { characters.indices.contains($0) }
    var indentation = true
    for offset in 0..<self.caret {
      let character = characters[offset]
      // The saved format cannot distinguish typed indentation from skipped spaces.
      let skipped = indentation && character == " "
      if !skipped && (mode == .strict || !self.mistakes.contains(offset)) {
        creditedOffsets.insert(offset)
      }
      if character == "\n" { indentation = true } else if character != " " { indentation = false }
    }
  }

  public mutating func resumeAtWordStart() {
    while caret > 0 && !characters[caret - 1].isWhitespace { caret -= 1 }
    pending = nil
    mistakes = mistakes.filter { $0 < caret }
    creditedOffsets = creditedOffsets.filter { $0 < caret }
  }

  public var expected: Character? { caret < characters.count ? characters[caret] : nil }
  public var needsExtension: Bool { characters.count - caret < 300 }
  public var netCorrectChars: Int { creditedOffsets.count }
  public var expectedGlyph: Character? { expected == " " ? "·" : expected }
  public var pendingKeyTag: Character? { pending == " " ? "␣" : pending }

  public mutating func append(_ text: String) {
    self.text.append(contentsOf: text)
    characters.append(contentsOf: text)
  }

  public mutating func setMode(_ mode: MistakeMode) {
    self.mode = mode
    pending = nil
  }

  @discardableResult
  public mutating func handle(_ input: Input) -> Change {
    switch input {
    case .backspace, .deleteWord:
      pending = nil
      guard mode == .forgiving, caret > 0 else { return .ignored }
      var start = caret - 1
      if case .deleteWord = input {
        // At a word boundary, remove preceding whitespace and the previous word.
        while start > 0 && characters[start].isWhitespace { start -= 1 }
        while start > 0 && !characters[start - 1].isWhitespace { start -= 1 }
      }
      let removed = creditedOffsets.filter { $0 >= start }
      creditedOffsets.subtract(removed)
      mistakes = mistakes.filter { $0 < start }
      caret = start
      return Change(expected: nil, typed: nil, netCorrectChars: -removed.count)
    case .character(let typed):
      guard let expected, typed != "\t", typed != "\r" else { return .ignored }
      guard typed != "\n" || expected == "\n" else { return .ignored }
      let correct = typed == expected
      if correct {
        creditedOffsets.insert(caret)
        pending = nil
        caret += 1
        if typed == "\n" {
          while caret < characters.count && characters[caret] == " " { caret += 1 }
        }
      } else {
        mistakes.insert(caret)
        if mode == .strict {
          pending = typed
        } else {
          caret += 1
        }
      }
      return Change(expected: expected, typed: typed, netCorrectChars: correct ? 1 : 0)
    }
  }
}
