import SwiftUI
import TwiddleCore

public struct HeaderView: View {
  @Environment(\.colorScheme) private var scheme
  let counters: StatsTracker.Counters
  let resumedWord: String?
  let paused: Bool
  let source: String
  let modeLabel: String
  let note: String?
  let blank: Bool
  let clock: String?
  let progress: Double?
  let finished: Bool

  public init(
    counters: StatsTracker.Counters, resumedWord: String?, paused: Bool, source: String,
    modeLabel: String = "Flow", note: String? = nil, blank: Bool = false,
    clock: String? = nil, progress: Double? = nil, finished: Bool = false
  ) {
    self.counters = counters
    self.resumedWord = resumedWord
    self.paused = paused
    self.source = source
    self.modeLabel = modeLabel
    self.note = note
    self.blank = blank
    self.clock = clock
    self.progress = progress
    self.finished = finished
  }

  public var body: some View {
    let theme = Theme(scheme)
    let wpmValue = Text(blank ? "–" : counters.wpm.formatted(.number.precision(.fractionLength(0))))
      .fontWeight(.medium).foregroundStyle(theme.primary)
    let accuracyValue = Text(
      blank ? "–" : (counters.accuracy * 100).formatted(.number.precision(.fractionLength(1)))
    )
    .fontWeight(.medium).foregroundStyle(theme.primary)
    HStack {
      HStack(spacing: Theme.labelGap) {
        if let resumedWord {
          Text("Resumed").fontWeight(.medium).foregroundStyle(theme.accent)
          Text("from the start of “\(resumedWord)”").foregroundStyle(theme.typed)
        } else if let note {
          Text(modeLabel).fontWeight(.medium).foregroundStyle(theme.primary)
          Text("·").foregroundStyle(theme.faint)
          Text(source).foregroundStyle(theme.secondary)
          Text(note).foregroundStyle(theme.typed)
        } else if blank {
          Text(modeLabel).fontWeight(.medium).foregroundStyle(theme.accent)
          Text("starts on your first key").foregroundStyle(theme.typed)
        } else {
          Text(modeLabel).fontWeight(.medium).foregroundStyle(theme.primary)
          Text("·").foregroundStyle(theme.faint)
          Text(source).foregroundStyle(theme.secondary)
        }
      }
      Spacer(minLength: Theme.labelGap)
      HStack(spacing: Theme.statGap) {
        if finished {
          Text("Finished")
        } else {
          if paused { Text("Paused") }
          if let clock { Text(clock).fontWeight(.semibold).foregroundStyle(theme.primary) }
          Text("\(wpmValue) wpm")
          Text("\(accuracyValue)%")
          Text("⌘")
            .font(.system(size: Theme.chipSize))
            .padding(.horizontal, Theme.chipPadding)
            .frame(height: Theme.chipHeight)
            .background(theme.cap, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
        }
      }
      .foregroundStyle(theme.typed)
    }
    .font(.system(size: Theme.labelSize))
    .monospacedDigit()
    .padding(.horizontal, Theme.inset)
    .padding(.top, Theme.headerTop)
    .frame(height: Theme.headerHeight)
    .offset(y: Theme.headerInkOffset)
    .overlay(alignment: .bottom) {
      if let progress {
        GeometryReader { geometry in
          Capsule().fill(theme.hair)
            .overlay(alignment: .leading) {
              Capsule().fill(theme.accent).frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: Theme.progressHeight)
        .padding(.horizontal, Theme.inset)
      }
    }
  }
}
