import Foundation

public struct PastedText: Equatable, Sendable {
  public let text: String

  public init?(_ input: String) {
    let capped = String(input.prefix(5_000))
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    var ascii = ""
    for scalar in capped.unicodeScalars {
      switch scalar {
      case "‘", "’": ascii += "'"
      case "“", "”": ascii += "\""
      case "–", "—": ascii += "-"
      case "\t": ascii += "    "
      default:
        if scalar == "\n" || (32...126).contains(scalar.value) {
          let character = Character(String(scalar))
          if FingerMap.resolve(character) != nil { ascii.append(character) }
        }
      }
    }
    let lines = ascii.split(separator: "\n", omittingEmptySubsequences: false)
      .map { String($0.reversed().drop(while: { $0 == " " }).reversed()) }
      .filter { !$0.isEmpty }
    let trimmed = lines.joined(separator: "\n")
    var normalized = ""
    var tokenLength = 0
    for character in trimmed {
      if character == " " || character == "\n" {
        tokenLength = 0
      } else {
        if tokenLength == TextLayout.maxLineLength {
          normalized.append(" ")
          tokenLength = 0
        }
        tokenLength += 1
      }
      normalized.append(character)
    }
    guard normalized.count >= 20 else { return nil }
    text = normalized
  }
}
