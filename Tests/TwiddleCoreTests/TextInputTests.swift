import Testing
import TwiddleCore

struct TextInputTests {
  @Test(arguments: [Character("\u{F702}"), "\u{F708}", "\u{F728}", "\u{F729}"])
  func navigationAndFunctionKeysAreIgnored(character: Character) {
    #expect(!isTextInput(character))
  }

  @Test(arguments: Array(UInt32(0)...0x1F) + [0x7F, 0xF700, 0xF8FF])
  func controlsAndPrivateUseBoundariesAreIgnored(value: UInt32) {
    #expect(!isTextInput(Character(String(Unicode.Scalar(value)!))))
  }

  @Test(arguments: [Character("a"), "å", " "])
  func textCountsAsAKey(character: Character) {
    #expect(isTextInput(character))
  }
}
