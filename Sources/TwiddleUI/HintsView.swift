import SwiftUI
import TwiddleCore

public struct HintsView: View {
  @Environment(\.colorScheme) private var scheme
  let hint: FingerMap.Resolved?

  public init(hint: FingerMap.Resolved?) { self.hint = hint }

  public var body: some View {
    let theme = Theme(scheme)
    HStack(spacing: Theme.hintsGap) {
      VStack(alignment: .leading, spacing: Theme.keyGap) {
        ForEach(FingerMap.rows.indices, id: \.self) { row in
          HStack(spacing: Theme.keyGap) {
            ForEach(FingerMap.rows[row], id: \.id) { key in keycap(key) }
          }
          .frame(maxWidth: .infinity, alignment: row == 4 ? .center : .leading)
        }
      }
      .frame(width: Theme.keyboardWidth)
      HStack(spacing: Theme.statGap) {
        Text(hint.map { String($0.label) } ?? "")
          .font(.system(size: Theme.nextKeyFont, weight: .medium, design: .monospaced))
          .frame(width: Theme.nextKeySize, height: Theme.nextKeySize)
          .foregroundStyle(theme.accentInk)
          .background(theme.accent, in: RoundedRectangle(cornerRadius: Theme.nextKeyRadius))
        VStack(alignment: .leading, spacing: Theme.resultStatGap) {
          Text(hint?.fingerName ?? "")
            .font(.system(size: Theme.fingerSize, weight: .medium))
            .foregroundStyle(theme.primary)
          Text(hint?.sublabel ?? "")
            .font(.system(size: Theme.labelSize)).foregroundStyle(theme.typed)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: Theme.hintTextWidth, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      hands
    }
    .padding(.horizontal, Theme.inset)
    .padding(.vertical, Theme.hintsInset)
    .frame(height: Theme.hintsHeight)
    .overlay(alignment: .top) { Rectangle().fill(theme.hair).frame(height: Theme.edgeWidth) }
  }

  private func keycap(_ key: FingerMap.Key) -> some View {
    let theme = Theme(scheme)
    let next = key.id == hint?.key
    let shift = key.id == hint?.shift?.rawValue
    let zone = key.finger != nil && key.finger == hint?.finger
    return Text(key.label)
      .font(.system(size: Theme.keySize, weight: .medium, design: .monospaced))
      .frame(
        width: key.units * Theme.keyUnit + (key.units - 1) * Theme.keyGap,
        height: Theme.keyHeight
      )
      .foregroundStyle(next ? theme.accentInk : zone || shift ? theme.primary : theme.typed)
      .background(
        next ? theme.accent : zone ? theme.zone : theme.key,
        in: RoundedRectangle(cornerRadius: Theme.keyRadius)
      )
      .overlay {
        if shift {
          RoundedRectangle(cornerRadius: Theme.keyRadius)
            .strokeBorder(theme.accent, lineWidth: Theme.capsuleSeparatorWidth)
        }
      }
  }

  private var hands: some View {
    let theme = Theme(scheme)
    let fingers: [FingerMap.Finger] = [
      .leftPinky, .leftRing, .leftMiddle, .leftIndex, .thumb,
      .thumb, .rightIndex, .rightMiddle, .rightRing, .rightPinky,
    ]
    let shift: FingerMap.Finger? =
      hint?.shift == .right ? .rightPinky : hint?.shift == .left ? .leftPinky : nil
    return HStack(alignment: .bottom, spacing: Theme.keyGap) {
      ForEach(fingers.indices, id: \.self) { index in
        RoundedRectangle(cornerRadius: Theme.handRadius)
          .fill(
            fingers[index] == hint?.finger
              ? theme.accent : fingers[index] == shift ? theme.zone : theme.key
          )
          .frame(width: Theme.handWidth, height: Theme.handHeights[index])
          .padding(.leading, index == 5 ? Theme.handGap : 0)
      }
    }
    .frame(height: Theme.handHeight, alignment: .bottom)
  }
}
