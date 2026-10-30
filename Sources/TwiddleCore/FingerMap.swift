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

    public var fingerName: String {
      let names: [Finger: String] = [
        .leftPinky: "Left pinky", .leftRing: "Left ring", .leftMiddle: "Left middle",
        .leftIndex: "Left index", .thumb: "Either thumb", .rightIndex: "Right index",
        .rightMiddle: "Right middle", .rightRing: "Right ring", .rightPinky: "Right pinky",
      ]
      return names[finger]! + (finger == .thumb ? "" : " finger")
    }

    public var sublabel: String {
      if let shift {
        return "Hold ⇧ with your " + (shift == .right ? "right" : "left") + " pinky"
      }
      if finger == .thumb { return "Space bar" }
      if key == "ret" { return "Return, reach from ;" }
      let home = FingerMap.home[finger]!
      return key == String(home) ? "Home row key" : "Reach from \(home)"
    }
  }

  public struct Key: Sendable {
    public let id: String
    public let label: String
    public let units: Double
    public let finger: Finger?

    private init(_ id: String, _ label: String? = nil, _ units: Double = 1, _ finger: Finger? = nil)
    {
      self.id = id
      self.label = label ?? id
      self.units = units
      self.finger = finger ?? FingerMap.resolve(Character(id))?.finger
    }

    fileprivate static func letters(_ text: String) -> [Key] {
      text.map { Key(String($0)) }
    }

    fileprivate static func special(
      _ id: String, _ label: String, _ units: Double, _ finger: Finger
    ) -> Key { Key(id, label, units, finger) }
  }

  public static let rows: [[Key]] = [
    Key.letters("`1234567890-=") + [.special("bksp", "⌫", 1.5, .rightPinky)],
    [.special("tab", "⇥", 1.5, .leftPinky)] + Key.letters("qwertyuiop[]\\"),
    [.special("caps", "⇪", 1.75, .leftPinky)] + Key.letters("asdfghjkl;'")
      + [.special("ret", "↩", 1.75, .rightPinky)],
    [.special("shiftL", "⇧", 2.25, .leftPinky)] + Key.letters("zxcvbnm,./")
      + [.special("shiftR", "⇧", 2.25, .rightPinky)],
    [.special("space", "", 6, .thumb)],
  ]

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
