import AppKit
import TwiddleCore

@MainActor
final class KeyRouter {
  private let model: PracticeModel
  private let hide: () -> Void

  init(model: PracticeModel, hide: @escaping () -> Void) {
    self.model = model
    self.hide = hide
  }

  func route(_ event: NSEvent) {
    guard event.type == .keyDown else { return }
    if event.keyCode == 53 {
      hide()
      return
    }
    if event.modifierFlags.contains(.command) {
      if event.charactersIgnoringModifiers?.lowercased() == "q" { NSApp.terminate(nil) }
      return
    }
    guard !event.modifierFlags.contains(.control),
      let characters = event.characters, !characters.isEmpty
    else { return }
    if event.keyCode == 51 {
      model.handle(event.modifierFlags.contains(.option) ? .deleteWord : .backspace)
      return
    }
    guard !event.isARepeat, event.keyCode != 48 else { return }
    if event.keyCode == 36 || event.keyCode == 76 {
      model.handle(.character("\n"))
      return
    }
    for character in characters where isTextInput(character) { model.handle(.character(character)) }
  }
}
