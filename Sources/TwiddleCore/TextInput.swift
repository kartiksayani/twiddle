public func isTextInput(_ character: Character) -> Bool {
  character.unicodeScalars.allSatisfy {
    $0.value >= 0x20 && $0.value != 0x7F && !(0xF700...0xF8FF).contains($0.value)
  }
}
