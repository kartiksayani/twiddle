import SwiftUI
import TwiddleCore

struct ResultView: View {
  @Environment(\.colorScheme) private var scheme
  let result: PracticeModel.SprintResult
  let length: Int

  var body: some View {
    let theme = Theme(scheme)
    HStack(alignment: .bottom, spacing: Theme.resultGap) {
      HStack(alignment: .firstTextBaseline, spacing: Theme.labelGap) {
        Text(result.counters.wpm.formatted(.number.precision(.fractionLength(0))))
          .font(.system(size: Theme.resultValueSize, weight: .semibold))
          .tracking(Theme.resultValueTracking)
          .frame(height: Theme.resultValueHeight)
          .foregroundStyle(theme.primary)
        Text("wpm").font(.system(size: Theme.resultUnitSize)).foregroundStyle(theme.secondary)
      }
      statistic(
        (result.counters.accuracy * 100).formatted(.number.precision(.fractionLength(1))) + "%",
        label: "accuracy")
      statistic(String(result.mistakes), label: "mistakes")
      statistic(result.slowestPair ?? "–", label: "slowest pair", mono: true)
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: Theme.resultActionGap) {
        action("↩", label: "Again, \(length) s", primary: true)
        action("⌘F", label: "Back to Flow")
        action("esc", label: "Hide")
      }
      .padding(.bottom, Theme.resultActionBottom)
    }
    .monospacedDigit()
    .padding(.horizontal, Theme.inset)
    .padding(.top, Theme.resultTop)
    .padding(.bottom, Theme.bodyBottom)
    .frame(height: Theme.bodyHeight, alignment: .bottom)
  }

  private func statistic(_ value: String, label: String, mono: Bool = false) -> some View {
    let theme = Theme(scheme)
    return VStack(alignment: .leading, spacing: Theme.resultStatGap) {
      Text(value)
        .font(
          .system(
            size: Theme.resultStatSize, weight: .medium, design: mono ? .monospaced : .default)
        )
        .foregroundStyle(theme.primary)
      Text(label).font(.system(size: Theme.labelSize)).foregroundStyle(theme.typed)
    }
    .padding(.bottom, Theme.resultStatGap)
  }

  private func action(_ key: String, label: String, primary: Bool = false) -> some View {
    let theme = Theme(scheme)
    return HStack(spacing: Theme.resultActionLabelGap) {
      Text(key).font(.system(size: Theme.chipSize))
        .frame(width: Theme.actionWidth, height: Theme.actionHeight)
        .foregroundStyle(primary ? theme.accentInk : theme.primary)
        .background(
          primary ? theme.accent : theme.cap,
          in: RoundedRectangle(cornerRadius: Theme.chipRadius))
      Text(label).font(.system(size: Theme.labelSize))
        .foregroundStyle(primary ? theme.primary : theme.secondary)
    }
  }
}
