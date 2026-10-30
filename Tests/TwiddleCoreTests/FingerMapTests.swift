import Testing
import TwiddleCore

struct FingerMapTests {
  @Test(arguments: Array(UInt8(32)...UInt8(126)))
  func everyPrintableASCIICharacterResolves(ascii: UInt8) throws {
    let character = Character(String(UnicodeScalar(ascii)))
    let resolved = try #require(FingerMap.resolve(character))
    #expect(FingerMap.rows.flatMap { $0 }.contains { $0.id == resolved.key })
    if let shift = resolved.shift {
      #expect(FingerMap.rows.flatMap { $0 }.contains { $0.id == shift.rawValue })
    }
    #expect(resolved.label == (character == " " ? "␣" : character))
  }

  @Test func fingerAssignmentsMatchPrototype() {
    let expected: [FingerMap.Finger: String] = [
      .leftPinky: "`1qaz", .leftRing: "2wsx", .leftMiddle: "3edc", .leftIndex: "45rtfgvb",
      .rightIndex: "67yuhjnm", .rightMiddle: "8ik,", .rightRing: "9ol.",
      .rightPinky: "0-=p[]\\;'/",
    ]
    #expect(FingerMap.fingers == expected)
    for (finger, keys) in expected {
      for key in keys {
        #expect(FingerMap.resolve(key)?.finger == finger)
        #expect(FingerMap.resolve(key)?.key == String(key))
        #expect(FingerMap.resolve(key)?.shift == nil)
      }
    }
  }

  @Test func shiftMappingsAndOppositeHandMatchPrototype() throws {
    let shifted = Array("~!@#$%^&*()_+{}|:\"<>?")
    let base = Array("`1234567890-=[]\\;',./")
    #expect(FingerMap.shifted.count == shifted.count)
    for (character, key) in zip(shifted, base) {
      let resolved = try #require(FingerMap.resolve(character))
      #expect(resolved.key == String(key))
      #expect(FingerMap.shifted[character] == key)
      #expect(resolved.finger == FingerMap.resolve(key)?.finger)
      #expect(resolved.shift == (resolved.finger.rawValue.hasPrefix("L") ? .right : .left))
    }
  }

  @Test(arguments: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
  func uppercaseUsesOppositeShift(character: Character) throws {
    let resolved = try #require(FingerMap.resolve(character))
    #expect(resolved.key == String(character).lowercased())
    #expect(resolved.shift == (resolved.finger.rawValue.hasPrefix("L") ? .right : .left))
  }

  @Test func spaceAndNewlineFollowPrototype() throws {
    let space = try #require(FingerMap.resolve(" "))
    #expect(space.key == "space")
    #expect(space.finger == .thumb)
    #expect(space.label == "␣")
    #expect(space.shift == nil)
    let newline = try #require(FingerMap.resolve("\n"))
    #expect(newline.key == "ret")
    #expect(newline.finger == .rightPinky)
    #expect(newline.label == "↩")
    #expect(newline.shift == nil)
  }

  @Test func homeKeysMatchPrototype() {
    #expect(
      FingerMap.home == [
        .leftPinky: "a", .leftRing: "s", .leftMiddle: "d", .leftIndex: "f",
        .rightIndex: "j", .rightMiddle: "k", .rightRing: "l", .rightPinky: ";",
      ])
  }

  @Test func hintNamesAndSublabelsMatchBoard() {
    let examples: [(Character, String, String)] = [
      ("a", "Left pinky finger", "Home row key"),
      ("w", "Left ring finger", "Reach from s"),
      ("e", "Left middle finger", "Reach from d"),
      ("T", "Left index finger", "Hold ⇧ with your right pinky"),
      (" ", "Either thumb", "Space bar"),
      ("y", "Right index finger", "Reach from j"),
      ("i", "Right middle finger", "Reach from k"),
      ("o", "Right ring finger", "Reach from l"),
      ("(", "Right ring finger", "Hold ⇧ with your left pinky"),
      ("\n", "Right pinky finger", "Return, reach from ;"),
    ]
    for (character, name, sublabel) in examples {
      #expect(FingerMap.resolve(character)?.fingerName == name)
      #expect(FingerMap.resolve(character)?.sublabel == sublabel)
    }
  }

  @Test(arguments: Array("\t\r\u{7f}é🙂"))
  func unsupportedCharactersDoNotResolve(character: Character) {
    #expect(FingerMap.resolve(character) == nil)
  }
}
