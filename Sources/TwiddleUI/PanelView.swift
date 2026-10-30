import SwiftUI
import TwiddleCore

public struct PanelView: View {
  @Environment(\.colorScheme) private var scheme
  private let model: PracticeModel
  private let snapshot: Bool

  public init(model: PracticeModel, snapshot: Bool = false) {
    self.model = model
    self.snapshot = snapshot
  }

  public var body: some View {
    let theme = Theme(scheme)
    VStack(spacing: 0) {
      HeaderView(
        counters: model.stats.today, resumedWord: model.resumedWord,
        paused: model.isPaused, source: "Words")
      PracticeTextView(
        session: model.session, characters: model.characters, lines: model.lines,
        blinks: !snapshot && model.caretBlinks)
    }
    .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
    .background(snapshot ? theme.solid : theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    .overlay(
      RoundedRectangle(cornerRadius: Theme.radius)
        .strokeBorder(theme.edge, lineWidth: Theme.edgeWidth))
  }
}
