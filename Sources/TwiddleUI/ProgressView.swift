import SwiftUI
import TwiddleCore

public struct ProgressView: View {
  @Environment(\.colorScheme) private var scheme
  let data: ProgressData

  public init(data: ProgressData) { self.data = data }

  public var body: some View {
    HStack(alignment: .top, spacing: Theme.progressGap) {
      VStack(alignment: .leading, spacing: Theme.progressStatGap) {
        statistic(data.minutes, label: "minutes practised")
        statistic(data.average, label: "average wpm")
        statistic(data.best, label: "best wpm")
      }
      trend
      weakestKeys
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .monospacedDigit()
    .padding(.horizontal, Theme.inset)
    .padding(.top, Theme.progressTop)
    .padding(.bottom, Theme.progressBottom)
    .frame(height: Theme.progressBodyHeight, alignment: .topLeading)
  }

  private func statistic(_ value: Double, label: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Theme.progressColumnGap) {
      Text(value.formatted(.number.precision(.fractionLength(0))))
        .font(.system(size: Theme.progressValueSize, weight: .semibold))
        .foregroundStyle(Theme(scheme).primary)
        .frame(minWidth: Theme.progressValueWidth, alignment: .leading)
      Text(label).font(.system(size: Theme.labelSize)).foregroundStyle(Theme(scheme).typed)
    }
    .fixedSize()
  }

  private var trend: some View {
    let theme = Theme(scheme)
    return VStack(spacing: Theme.progressColumnGap) {
      HStack {
        Text("WPM, last 20 runs")
        Spacer(minLength: 0)
        Text("best \(data.chartBest.formatted(.number.precision(.fractionLength(0))))")
      }
      .font(.system(size: Theme.labelSize))
      Canvas { context, size in
        guard !data.points.isEmpty else { return }
        func point(_ value: ProgressData.Point) -> CGPoint {
          CGPoint(x: value.x * size.width, y: value.y * size.height)
        }
        var average = Path()
        average.move(to: CGPoint(x: 0, y: data.averageY * size.height))
        average.addLine(to: CGPoint(x: size.width, y: data.averageY * size.height))
        context.stroke(
          average, with: .color(theme.hairStrong),
          style: StrokeStyle(lineWidth: Theme.capsuleSeparatorWidth, dash: Theme.chartDash))
        var line = Path()
        line.addLines(data.points.map(point))
        context.stroke(
          line, with: .color(theme.accent),
          style: StrokeStyle(lineWidth: Theme.chartLineWidth, lineCap: .round, lineJoin: .round))
        if let best = data.bestPoint {
          let center = point(best)
          let radius = Theme.chartBestRadius
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(theme.accent))
        }
        if let last = data.points.last {
          let center = point(last)
          let radius = Theme.chartLastRadius
          let circle = Path(
            ellipseIn: CGRect(
              x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
          context.fill(circle, with: .color(theme.solid))
          context.stroke(circle, with: .color(theme.accent), lineWidth: Theme.chartLineWidth)
        }
      }
      .frame(height: Theme.chartHeight)
      HStack {
        Text(data.oldestDate.map { $0.formatted(.dateTime.weekday(.abbreviated)) } ?? "")
        Spacer(minLength: 0)
        Text(data.isEmpty ? "" : "dashed: today's average")
        Spacer(minLength: 0)
        Text(data.isEmpty ? "" : "now")
      }
      .font(.system(size: Theme.chipSize))
    }
    .foregroundStyle(theme.typed)
    .frame(width: Theme.chartWidth)
    .overlay {
      if data.isEmpty {
        Text("Numbers appear after your first run")
          .font(.system(size: Theme.labelSize)).foregroundStyle(theme.typed)
          .fixedSize()
      }
    }
  }

  private var weakestKeys: some View {
    let theme = Theme(scheme)
    return VStack(alignment: .leading, spacing: Theme.progressColumnGap) {
      Text("Weakest keys").font(.system(size: Theme.labelSize))
      HStack(spacing: Theme.progressColumnGap) {
        ForEach(data.weakestKeys, id: \.key) { key in
          VStack(spacing: Theme.resultActionGap) {
            Text(String(key.key))
              .font(.system(size: Theme.weakKeyFont, weight: .medium, design: .monospaced))
              .frame(width: Theme.weakKeySize, height: Theme.weakKeySize)
              .foregroundStyle(theme.primary)
              .background(theme.cap, in: RoundedRectangle(cornerRadius: Theme.weakKeyRadius))
              .overlay(alignment: .bottom) {
                UnevenRoundedRectangle(
                  bottomLeadingRadius: Theme.weakKeyRadius,
                  bottomTrailingRadius: Theme.weakKeyRadius
                ).fill(theme.hairStrong).frame(height: Theme.capsuleSeparatorWidth)
              }
              .clipShape(RoundedRectangle(cornerRadius: Theme.weakKeyRadius))
            Text(key.stats.averageMs.formatted(.number.precision(.fractionLength(0))))
              .font(.system(size: Theme.chipSize))
          }
        }
      }
      .frame(height: Theme.weakKeyRowHeight, alignment: .top)
      Text("average ms per key").font(.system(size: Theme.chipSize))
    }
    .foregroundStyle(theme.typed)
    .frame(width: Theme.weakColumnWidth, alignment: .leading)
  }
}
