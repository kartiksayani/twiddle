import SwiftUI
import TwiddleCore

public struct PracticeTextView: View {
  @Environment(\.colorScheme) private var scheme
  let session: TypingSession
  let characters: [Character]
  let lines: [Range<Int>]
  let blinks: Bool

  public init(session: TypingSession, characters: [Character], lines: [Range<Int>], blinks: Bool) {
    self.session = session
    self.characters = characters
    self.lines = lines
    self.blinks = blinks
  }

  private var visibleLines: [Range<Int>] {
    let current = lines.lastIndex(where: { $0.lowerBound <= session.caret }) ?? 0
    return Array(lines.dropFirst(current).prefix(2))
  }

  public var body: some View {
    TimelineView(.animation(minimumInterval: Theme.blinkPeriod / 2, paused: !blinks)) { timeline in
      VStack(spacing: 0) {
        ForEach(visibleLines, id: \.lowerBound) { line in
          Canvas { context, _ in
            draw(
              line, in: &context,
              caretVisible: !blinks
                || timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(
                  dividingBy: Theme.blinkPeriod) < Theme.blinkPeriod / 2
            )
          }
          .frame(height: Theme.rowHeight)
          .offset(y: Theme.practiceInkOffset)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .padding(.horizontal, Theme.inset)
    .padding(.top, Theme.bodyTop)
    .padding(.bottom, Theme.bodyBottom)
    .frame(height: Theme.bodyHeight)
    .clipped()
  }

  private func draw(_ line: Range<Int>, in context: inout GraphicsContext, caretVisible: Bool) {
    let theme = Theme(scheme)
    let font = Theme.practiceFont
    // A single glyph measurement rounds up; average a run to retain the font’s advance.
    let sampleCount = 100
    let cell =
      context.resolve(Text(String(repeating: "M", count: sampleCount)).font(font)).measure(
        in: .init(width: .infinity, height: .infinity)
      ).width / CGFloat(sampleCount)
    for offset in line {
      let character = characters[offset]
      let waiting = offset == session.caret && session.pending != nil
      let glyph = character == "\n" ? "↵" : waiting && character == " " ? "·" : String(character)
      let color =
        waiting
        ? theme.error
        : character == "\n"
          ? theme.faint
          : offset < session.caret ? theme.typed : theme.primary
      let x = CGFloat(offset - line.lowerBound) * cell
      context.draw(
        Text(glyph).font(font).foregroundStyle(color),
        at: CGPoint(x: x, y: Theme.rowHeight / 2), anchor: .leading)
      if waiting {
        context.draw(
          Text(String(session.pendingKeyTag!))
            .font(.system(size: Theme.tagSize, weight: .semibold)).foregroundStyle(theme.error),
          at: CGPoint(x: x + cell / 2, y: Theme.tagTop), anchor: .top)
        var wave = Path()
        let waveY = Theme.underlineY + Theme.waveHeight / 2
        let waveStep = cell / 2
        wave.move(to: CGPoint(x: x, y: waveY))
        var step: CGFloat = 0
        while step < cell {
          let end = min(step + waveStep, cell)
          wave.addQuadCurve(
            to: CGPoint(x: x + end, y: waveY),
            control: CGPoint(
              x: x + (step + end) / 2,
              y: waveY
                + (Int(step / waveStep).isMultiple(of: 2)
                  ? Theme.waveHeight : -Theme.waveHeight)))
          step = end
        }
        context.stroke(wave, with: .color(theme.error), lineWidth: Theme.underlineWidth)
      } else if offset < session.caret && session.mistakes.contains(offset) {
        var dots = Path()
        dots.move(to: CGPoint(x: x, y: Theme.underlineY))
        dots.addLine(to: CGPoint(x: x + cell, y: Theme.underlineY))
        context.stroke(
          dots, with: .color(theme.error),
          style: StrokeStyle(
            lineWidth: Theme.underlineWidth, lineCap: .round,
            dash: [Theme.dotLength, Theme.dotGap]))
      }
      if offset == session.caret && caretVisible {
        let rect = CGRect(
          x: x - Theme.caretOffset, y: Theme.caretInset,
          width: Theme.caretWidth, height: Theme.rowHeight - 2 * Theme.caretInset)
        context.fill(
          Path(roundedRect: rect, cornerRadius: Theme.caretOffset), with: .color(theme.accent))
      }
    }
  }
}
