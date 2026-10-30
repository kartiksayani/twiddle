import SwiftUI
import TwiddleCore

public struct IntroView: View {
  @Environment(\.colorScheme) private var scheme
  private let shortcut: Hotkey?
  public init(hotkey: Hotkey? = .standard) { shortcut = hotkey }

  public var body: some View {
    let theme = Theme(scheme)
    VStack(alignment: .leading, spacing: Theme.introGap) {
      HStack(spacing: Theme.labelGap) {
        Text(shortcut == nil ? "Open" : "Press")
        HStack(spacing: Theme.introKeyGap) {
          if let shortcut {
            ForEach(shortcut.parts, id: \.self) { hotkey($0) }
          } else {
            Text("Practise in the menu bar")
          }
        }
        .padding(.horizontal, Theme.introKeyGap)
        Text("anywhere to practise.")
      }
      .font(.system(size: Theme.introFont, weight: .medium))
      .foregroundStyle(theme.primary)
      .frame(height: Theme.introLineHeight)
      HStack(spacing: Theme.introFooterGap) {
        HStack(spacing: Theme.labelGap) {
          Text("esc").font(.system(size: Theme.tagSize))
            .padding(.horizontal, Theme.introEscapeInset)
            .frame(height: Theme.actionHeight)
            .foregroundStyle(theme.primary)
            .background(theme.cap, in: RoundedRectangle(cornerRadius: Theme.chipRadius))
          Text("hides it. Next time it picks up where you left off.")
        }
        .foregroundStyle(theme.secondary)
        Spacer(minLength: 0)
        Text("Start typing").fontWeight(.medium).foregroundStyle(theme.accent)
      }
      .font(.system(size: Theme.fingerSize))
    }
    .padding(.horizontal, Theme.inset)
    .padding(.top, Theme.introTop)
    .padding(.bottom, Theme.bodyBottom)
    .frame(height: Theme.bodyHeight, alignment: .bottom)
  }

  private func hotkey(_ label: String) -> some View {
    Text(label).font(.system(size: Theme.introKeyFont, weight: .medium))
      .padding(.horizontal, label == "Space" ? Theme.introSpaceInset : Theme.introKeyInset)
      .frame(height: Theme.introKeyHeight)
      .background(Theme(scheme).cap, in: RoundedRectangle(cornerRadius: Theme.introKeyRadius))
  }
}
