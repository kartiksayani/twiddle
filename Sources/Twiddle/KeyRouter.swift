import AppKit
import TwiddleCore

@MainActor
final class KeyRouter {
  private let model: PracticeModel
  private let hide: () -> Void
  private let layoutChanged: () -> Void
  var openSettings: () -> Void = {}

  init(
    model: PracticeModel, hide: @escaping () -> Void,
    layoutChanged: @escaping () -> Void
  ) {
    self.layoutChanged = layoutChanged
    self.model = model
    self.hide = hide
  }

  func route(_ event: NSEvent) {
    defer { layoutChanged() }
    if event.type == .flagsChanged {
      model.handleCapsule(event.modifierFlags.contains(.command) ? .commandDown : .commandUp)
      return
    }
    guard event.type == .keyDown else { return }
    if event.keyCode == 53 {
      hide()
      return
    }
    if event.modifierFlags.contains(.command) {
      model.handleCapsule(.chord)
      guard !event.isARepeat else { return }
      if event.keyCode == 36 || event.keyCode == 76 {
        model.handle(.freshText)
        return
      }
      switch event.charactersIgnoringModifiers?.lowercased() {
      case "1": model.handle(.source(.words))
      case "2": model.handle(.source(.code))
      case "3": model.handle(.source(.prose))
      case "4": model.handle(.source(.weakKeys))
      case "5": model.handle(.source(.symbols))
      case "v":
        guard model.isVisible, model.view != .intro else { return }
        model.paste(NSPasteboard.general.string(forType: .string))
      case "f": model.handle(.flow)
      case "s": model.handle(.sprint)
      case "/": model.handle(.toggleHints)
      case "p": model.handle(.progress)
      case ",": openSettings()
      case "q": NSApp.terminate(nil)
      default: break
      }
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
