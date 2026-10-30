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
      if model.view == .text {
        HeaderView(
          counters: model.headerCounters, resumedWord: model.resumedWord,
          paused: model.mode == .flow && model.isPaused, source: model.sourceLabel,
          modeLabel: model.mode == .flow ? "Flow" : "Sprint \(model.sprintLength) s",
          note: model.contentNote, blank: model.mode == .sprint && model.sprintState == .ready,
          clock: model.mode == .sprint
            ? String(format: "%d:%02d", model.sprintRemaining / 60, model.sprintRemaining % 60)
            : nil,
          progress: model.mode == .sprint && model.sprintState != .result
            ? model.sprintElapsed / Double(model.sprintLength) : nil,
          finished: model.mode == .sprint && model.sprintState == .result)
        if let result = model.result, model.mode == .sprint {
          ResultView(result: result, length: model.sprintLength)
        } else {
          PracticeTextView(
            session: model.session, characters: model.characters, lines: model.lines,
            blinks: !snapshot && model.caretBlinks, ghostOffset: model.ghostOffset)
        }
      } else {
        HStack {
          Text(model.view == .progress ? "Today" : "Twiddle")
            .fontWeight(.medium).foregroundStyle(theme.accent)
          Spacer()
          Text(model.view == .progress ? "Type to go back" : "Change the hotkey in Settings, ⌘,")
            .foregroundStyle(theme.typed)
        }
        .font(.system(size: Theme.labelSize))
        .padding(.horizontal, Theme.inset)
        .padding(.top, Theme.headerTop)
        .frame(height: Theme.headerHeight)
        .offset(y: Theme.headerInkOffset)
        if model.view == .progress {
          ProgressView(data: model.progress)
        } else {
          IntroView(hotkey: model.hotkey)
        }
      }
      if model.showsHints { HintsView(hint: model.hint) }
    }
    .frame(width: Theme.panelSize.width, height: model.panelHeight)
    .background(snapshot ? theme.solid : theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    .overlay(
      RoundedRectangle(cornerRadius: Theme.radius)
        .strokeBorder(theme.edge, lineWidth: Theme.edgeWidth))
  }
}
