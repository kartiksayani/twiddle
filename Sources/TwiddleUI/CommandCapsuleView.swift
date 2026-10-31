import SwiftUI
import TwiddleCore

public struct CommandCapsuleView: View {
  @Environment(\.colorScheme) private var scheme
  private let model: PracticeModel
  private let snapshot: Bool

  public init(model: PracticeModel, snapshot: Bool = false) {
    self.model = model
    self.snapshot = snapshot
  }

  public var body: some View {
    let theme = Theme(scheme)
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: Theme.capsuleGap) {
        item("⌘1", "Words", selected: model.source == .words)
        item("⌘2", "Code", selected: model.source == .code)
        item("⌘3", "Prose", selected: model.source == .prose)
        item("⌘4", "Weak keys", selected: model.source == .weakKeys)
        item("⌘5", "Symbols", selected: model.source == .symbols)
        item("⌘V", "Paste", selected: model.source == .pasted)
      }
      .frame(height: Theme.capsuleHeight / 2)
      HStack(spacing: Theme.capsuleGap) {
        item("⌘F", "Flow", selected: model.mode == .flow)
        item("⌘S", "Sprint", selected: model.mode == .sprint)
        separator
        item("⌘/", "Hints", selected: model.hintsOn)
        item("⌘P", "Progress", selected: model.view == .progress)
        item("⌘,", "Settings")
      }
      .frame(height: Theme.capsuleHeight / 2)
    }
    .fixedSize()
    .padding(.horizontal, Theme.capsuleInset)
    .frame(height: Theme.capsuleHeight)
    .background(
      snapshot ? theme.solid : theme.surface,
      in: RoundedRectangle(cornerRadius: Theme.capsuleRadius)
    )
    .overlay {
      RoundedRectangle(cornerRadius: Theme.capsuleRadius)
        .strokeBorder(theme.edge, lineWidth: Theme.edgeWidth)
    }
  }

  private var separator: some View {
    Rectangle().fill(Theme(scheme).hairStrong)
      .frame(width: Theme.capsuleSeparatorWidth, height: Theme.capsuleSeparatorHeight)
  }

  private func item(_ key: String, _ label: String, selected: Bool = false) -> some View {
    let theme = Theme(scheme)
    return HStack(spacing: Theme.capsuleLabelGap) {
      Text(key).font(.system(size: Theme.chipSize))
        .padding(.horizontal, Theme.chipPadding)
        .frame(height: Theme.actionHeight)
        .foregroundStyle(theme.primary)
        .background(theme.cap, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
      Text(label).font(.system(size: Theme.tagSize, weight: selected ? .semibold : .regular))
        .foregroundStyle(selected ? theme.primary : theme.secondary)
    }
  }
}
