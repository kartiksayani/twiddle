import SwiftUI
import TwiddleCore

public struct HeaderView: View {
  @Environment(\.colorScheme) private var scheme
  let counters: StatsTracker.Counters
  let resumedWord: String?
  let paused: Bool
  let source: String

  public init(counters: StatsTracker.Counters, resumedWord: String?, paused: Bool, source: String) {
    self.counters = counters
    self.resumedWord = resumedWord
    self.paused = paused
    self.source = source
  }

  public var body: some View {
    let theme = Theme(scheme)
    let wpmValue = Text(counters.wpm.formatted(.number.precision(.fractionLength(0))))
      .fontWeight(.medium).foregroundStyle(theme.primary)
    let accuracyValue = Text(
      (counters.accuracy * 100).formatted(.number.precision(.fractionLength(1)))
    )
    .fontWeight(.medium).foregroundStyle(theme.primary)
    HStack {
      HStack(spacing: Theme.labelGap) {
        if let resumedWord {
          Text("Resumed").fontWeight(.medium).foregroundStyle(theme.accent)
          Text("from the start of “\(resumedWord)”").foregroundStyle(theme.typed)
        } else {
          Text("Flow").fontWeight(.medium).foregroundStyle(theme.primary)
          Text("·").foregroundStyle(theme.faint)
          Text(source).foregroundStyle(theme.secondary)
        }
      }
      Spacer(minLength: Theme.labelGap)
      HStack(spacing: Theme.statGap) {
        if paused { Text("Paused") }
        Text("\(wpmValue) wpm")
        Text("\(accuracyValue)%")
        Text("⌘")
          .font(.system(size: Theme.chipSize))
          .padding(.horizontal, Theme.chipPadding)
          .frame(height: Theme.chipHeight)
          .background(theme.cap, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
      }
      .foregroundStyle(theme.typed)
    }
    .font(.system(size: Theme.labelSize))
    .monospacedDigit()
    .padding(.horizontal, Theme.inset)
    .padding(.top, Theme.headerTop)
    .frame(height: Theme.headerHeight)
    .offset(y: Theme.headerInkOffset)
  }
}
