public enum TextLayout {
  /// 45 SF Mono cells fit the 668 pt text column; the last holds a trailing space or line break.
  static let maxLineLength = 44

  /// Offset ranges retain spaces and newlines, exactly as the panel prototype does.
  public static func layout(_ text: String) -> [Range<Int>] {
    let characters = Array(text)
    var lines: [Range<Int>] = []
    var start = 0
    while start < characters.count {
      let hardEnd =
        characters[start...].firstIndex(of: "\n").map { $0 + 1 }
        ?? characters.count
      var lineStart = start
      var wordStart = start
      while wordStart < hardEnd {
        let wordEnd =
          characters[wordStart..<hardEnd].firstIndex(of: " ").map { $0 + 1 }
          ?? hardEnd
        if wordEnd - lineStart - 1 > maxLineLength && wordStart > lineStart {
          lines.append(lineStart..<wordStart)
          lineStart = wordStart
        }
        wordStart = wordEnd
      }
      lines.append(lineStart..<hardEnd)
      start = hardEnd
    }
    return lines
  }
}
