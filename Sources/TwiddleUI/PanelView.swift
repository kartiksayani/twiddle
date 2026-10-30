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
        counters: model.headerCounters, resumedWord: model.resumedWord,
        paused: model.mode == .flow && model.isPaused, source: model.source.label,
        modeLabel: model.mode == .flow ? "Flow" : "Sprint \(model.sprintLength) s",
        note: model.contentNote, blank: model.mode == .sprint && model.sprintState == .ready,
        clock: model.mode == .sprint
          ? String(format: "%d:%02d", model.sprintRemaining / 60, model.sprintRemaining % 60) : nil,
        progress: model.mode == .sprint && model.sprintState != .result
          ? model.sprintElapsed / Double(model.sprintLength) : nil,
        finished: model.mode == .sprint && model.sprintState == .result)
      if let result = model.result, model.mode == .sprint {
        ResultView(result: result, length: model.sprintLength)
      } else {
        PracticeTextView(
          session: model.session, characters: model.characters, lines: model.lines,
          blinks: !snapshot && model.caretBlinks)
      }
    }
    .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
    .background(snapshot ? theme.solid : theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    .overlay(
      RoundedRectangle(cornerRadius: Theme.radius)
        .strokeBorder(theme.edge, lineWidth: Theme.edgeWidth))
  }
}
