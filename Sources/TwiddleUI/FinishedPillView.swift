import SwiftUI

public struct FinishedPillView: View {
  @Environment(\.colorScheme) private var scheme
  private let snapshot: Bool

  public init(snapshot: Bool = false) {
    self.snapshot = snapshot
  }

  public var body: some View {
    let theme = Theme(scheme)
    HStack(spacing: Theme.capsuleGap) {
      Image(systemName: "checkmark")
        .font(.system(size: Theme.tagSize, weight: .semibold))
        .foregroundStyle(theme.accent)
      Text("Finished")
        .font(.system(size: Theme.tagSize))
        .foregroundStyle(theme.primary)
      Text("esc")
        .font(.system(size: Theme.chipSize))
        .padding(.horizontal, Theme.chipPadding)
        .frame(height: Theme.actionHeight)
        .foregroundStyle(theme.primary)
        .background(theme.cap, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
    }
    .fixedSize()
    .padding(.horizontal, Theme.capsuleInset)
    .frame(height: Theme.finishedHeight)
    .background(
      snapshot ? theme.solid : theme.surface,
      in: RoundedRectangle(cornerRadius: Theme.capsuleRadius)
    )
    .overlay {
      RoundedRectangle(cornerRadius: Theme.capsuleRadius)
        .strokeBorder(theme.edge, lineWidth: Theme.edgeWidth)
    }
  }
}
