public enum FingerMap {
  public enum Finger: String, Sendable, CaseIterable {
    case leftPinky = "L5"
    case leftRing = "L4"
    case leftMiddle = "L3"
    case leftIndex = "L2"
    case thumb = "T"
    case rightIndex = "R2"
    case rightMiddle = "R3"
    case rightRing = "R4"
    case rightPinky = "R5"
  }

  public enum Shift: String, Sendable {
    case left = "shiftL"
    case right = "shiftR"
  }

  public struct Resolved: Equatable, Sendable {
    public let key: String
    public let finger: Finger
    public let label: Character
    public let shift: Shift?
  }

  public static let fingers: [Finger: String] = [
    .leftPinky: "`1qaz", .leftRing: "2wsx", .leftMiddle: "3edc", .leftIndex: "45rtfgvb",
    .rightIndex: "67yuhjnm", .rightMiddle: "8ik,", .rightRing: "9ol.",
    .rightPinky: "0-=p[]\\;'/",
  ]

  public static let home: [Finger: Character] = [
    .leftPinky: "a", .leftRing: "s", .leftMiddle: "d", .leftIndex: "f",
    .rightIndex: "j", .rightMiddle: "k", .rightRing: "l", .rightPinky: ";",
  ]

  public static let shifted: [Character: Character] = [
    "~": "`", "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
    "*": "8", "(": "9", ")": "0", "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\",
    ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/",
  ]

  public static func resolve(_ character: Character) -> Resolved? {
    if character == " " {
      return Resolved(key: "space", finger: .thumb, label: "␣", shift: nil)
    }
    if character == "\n" {
      return Resolved(key: "ret", finger: .rightPinky, label: "↩", shift: nil)
    }
    let lowercased = String(character).lowercased()
    let key = shifted[character].map(String.init) ?? lowercased
    guard let finger = fingers.first(where: { $0.value.contains(key) })?.key else { return nil }
    let needsShift = shifted[character] != nil || String(character) != lowercased
    return Resolved(
      key: key, finger: finger, label: character,
      shift: needsShift ? (finger.rawValue.hasPrefix("L") ? .right : .left) : nil)
  }
}
