import SwiftUI

public struct Theme {
  public static let settingsSize = CGSize(width: 500, height: 468)
  public static let settingsTitleHeight: CGFloat = 40
  public static let settingsTop: CGFloat = 6
  public static let settingsBottom: CGFloat = 22
  public static let settingsInset: CGFloat = 20
  public static let settingsGroupGap: CGFloat = 16
  public static let settingsRadius: CGFloat = 9
  public static let settingsRowHeight: CGFloat = 44
  public static let settingsDetailHeight: CGFloat = 56
  public static let settingsRowInset: CGFloat = 12
  public static let settingsFont: CGFloat = 13
  public static let settingsControlFont: CGFloat = 12
  public static let settingsHelpFont: CGFloat = 11
  public static let settingsHelpGap: CGFloat = 2
  public static let settingsMessageHeight: CGFloat = 20
  public static let settingsCompactGap: CGFloat = 8
  public static let settingsCompactBottom: CGFloat = 18
  public static let settingsControlHeight: CGFloat = 24
  public static let settingsRecordingHeight: CGFloat = 26
  public static let settingsMenuHeight: CGFloat = 22
  public static let settingsControlRadius: CGFloat = 6
  public static let settingsControlInset: CGFloat = 10
  public static let settingsSegmentInset: CGFloat = 2
  public static let settingsSegmentInsetX: CGFloat = 14
  public static let settingsThemeSegmentInset: CGFloat = 12
  public static let settingsMenuGap: CGFloat = 18
  public static let settingsMenuArrowSize: CGFloat = 9
  public static let settingsHotkeyWidth: CGFloat = 120
  public static let settingsRecordingWidth: CGFloat = 150
  public static let settingsToggleWidth: CGFloat = 32
  public static let settingsToggleHeight: CGFloat = 18
  public static let settingsToggleKnob: CGFloat = 14
  public static let settingsClearSize: CGFloat = 14
  public static let settingsFocusWidth: CGFloat = 3
  public static let settingsFocusOpacity: Double = 0.5
  public static let settingsGroupOpacity: Double = 0.04
  public static let settingsSelectedOpacity: Double = 0.2
  public static let statusIconSize = CGSize(width: 18, height: 16)
  public static let statusIconRect = CGRect(x: 1.75, y: 2.75, width: 14.5, height: 10.5)
  public static let statusIconStroke: CGFloat = 1.5
  public static let statusIconRadius: CGFloat = 3.5
  public static let statusCaretRect = CGRect(x: 5.5, y: 5.5, width: 1.5, height: 5)
  public static let hintsHeight: CGFloat = 116
  public static let hintsInset: CGFloat = 14
  public static let hintsGap: CGFloat = 30
  public static let keyGap: CGFloat = 3
  public static let keyboardWidth: CGFloat = 287
  public static let keyUnit: CGFloat = 17
  public static let keyHeight: CGFloat = 15
  public static let keyRadius: CGFloat = 3
  public static let keySize: CGFloat = 8.5
  public static let nextKeySize: CGFloat = 36
  public static let nextKeyRadius: CGFloat = 7
  public static let nextKeyFont: CGFloat = 17
  public static let fingerSize: CGFloat = 13
  public static let hintTextWidth: CGFloat = 165
  public static let handWidth: CGFloat = 7
  public static let handRadius: CGFloat = 3.5
  public static let handGap: CGFloat = 9
  public static let handHeight: CGFloat = 28
  public static let handHeights: [CGFloat] = [15, 21, 24, 21, 11, 11, 21, 24, 21, 15]
  public static let progressBodyHeight: CGFloat = 224
  public static let progressTop: CGFloat = 18
  public static let progressBottom: CGFloat = 22
  public static let progressGap: CGFloat = 40
  public static let progressColumnGap: CGFloat = 8
  public static let progressStatGap: CGFloat = 10
  public static let progressValueSize: CGFloat = 20
  public static let progressValueWidth: CGFloat = 48
  public static let chartWidth: CGFloat = 250
  public static let chartHeight: CGFloat = 70
  public static let chartLineWidth: CGFloat = 1.75
  public static let chartBestRadius: CGFloat = 3
  public static let chartLastRadius: CGFloat = 3.5
  public static let chartDash: [CGFloat] = [2, 3]
  public static let weakColumnWidth: CGFloat = 182
  public static let weakKeyRowHeight: CGFloat = 48
  public static let weakKeySize: CGFloat = 30
  public static let weakKeyRadius: CGFloat = 6
  public static let weakKeyFont: CGFloat = 15
  public static let introTop: CGFloat = 8
  public static let introGap: CGFloat = 10
  public static let introFont: CGFloat = 19
  public static let introLineHeight: CGFloat = 26
  public static let introKeyGap: CGFloat = 3
  public static let introKeyInset: CGFloat = 7
  public static let introSpaceInset: CGFloat = 9
  public static let introKeyHeight: CGFloat = 24
  public static let introKeyRadius: CGFloat = 5
  public static let introKeyFont: CGFloat = 14
  public static let introEscapeInset: CGFloat = 5
  public static let introFooterGap: CGFloat = 16
  public static let progressHeight: CGFloat = 2
  public static let resultTop: CGFloat = 10
  public static let resultGap: CGFloat = 24
  public static let resultValueSize: CGFloat = 40
  public static let resultValueHeight: CGFloat = 44
  public static let resultValueTracking: CGFloat = -0.8
  public static let resultUnitSize: CGFloat = 14
  public static let resultStatSize: CGFloat = 17
  public static let resultStatGap: CGFloat = 4
  public static let resultActionGap: CGFloat = 5
  public static let resultActionLabelGap: CGFloat = 7
  public static let resultActionBottom: CGFloat = 2
  public static let actionHeight: CGFloat = 18
  public static let actionWidth: CGFloat = 26
  public static let capsuleHeight: CGFloat = 64
  public static let finishedHeight: CGFloat = capsuleHeight / 2
  public static let capsuleOffset: CGFloat = 10
  public static let capsuleGap: CGFloat = 10
  public static let capsuleInset: CGFloat = 12
  public static let capsuleRadius: CGFloat = 10
  public static let capsuleLabelGap: CGFloat = 5
  public static let capsuleSeparatorHeight: CGFloat = 14
  public static let capsuleSeparatorWidth: CGFloat = 1
  public static let clockTick = 0.05
  public static let panelSize = CGSize(width: 720, height: 136)
  public static let headerHeight: CGFloat = 32
  public static let bodyHeight: CGFloat = 104
  public static let inset: CGFloat = 26
  public static let bodyTop: CGFloat = 12
  public static let bodyBottom: CGFloat = 20
  public static let rowHeight: CGFloat = 36
  public static let practiceSize: CGFloat = 24
  public static let practiceFont = Font.system(size: practiceSize, design: .monospaced)
  public static let labelSize: CGFloat = 11.5
  public static let tagSize: CGFloat = 11
  public static let chipSize: CGFloat = 10.5
  public static let chipHeight: CGFloat = 16
  public static let chipPadding: CGFloat = 4
  public static let chipRadius: CGFloat = 4
  public static let headerTop: CGFloat = 2
  // Match the board’s content-box header ink while retaining the specified 136 pt total.
  public static let headerInkOffset: CGFloat = 1
  public static let practiceInkOffset: CGFloat = 2
  public static let labelGap: CGFloat = 6
  public static let statGap: CGFloat = 14
  public static let radius: CGFloat = 16
  public static let edgeWidth: CGFloat = 0.5
  public static let caretWidth: CGFloat = 2
  public static let caretInset: CGFloat = 5
  public static let caretOffset: CGFloat = 1
  public static let tagTop: CGFloat = -4
  public static let underlineY: CGFloat = 34
  public static let underlineWidth: CGFloat = 1.5
  public static let waveHeight: CGFloat = 4
  public static let dotLength: CGFloat = 0.1
  public static let dotGap: CGFloat = 3
  public static let blinkPeriod = 1.06
  public static let bottomOffset: CGFloat = 40
  public static let summonRise: CGFloat = 8
  public static let summonDuration = 0.18
  public static let hideDuration = 0.12

  public let key: Color
  public let zone: Color
  public let hairStrong: Color
  public let hair: Color
  public let accentInk: Color
  public let surface: Color
  public let solid: Color
  public let primary: Color
  public let secondary: Color
  public let typed: Color
  public let faint: Color
  public let accent: Color
  public let error: Color
  public let cap: Color
  public let edge: Color
  public let settingsBackground: Color
  public let settingsGroup: Color
  public let settingsSelection: Color
  public let toggleOnInk: Color
  public let toggleOffInk: Color
  public let settingsAccent: Color
  public let settingsConflict: Color

  public init(_ scheme: ColorScheme) {
    let dark = scheme == .dark
    settingsBackground = Self.rgb(dark ? 0x232326 : 0xF6F6F8)
    settingsGroup = (dark ? Color.white : Color.black).opacity(Self.settingsGroupOpacity)
    settingsSelection = Color.white.opacity(dark ? Self.settingsSelectedOpacity : 0.9)
    toggleOnInk = .white
    toggleOffInk = Self.rgb(dark ? 0xD8D8DC : 0xFFFFFF)
    settingsAccent = Color(.sRGB, red: 0.562288, green: 0.423983, blue: 0.878559)
    hairStrong = (dark ? Color.white : Color.black).opacity(0.16)
    hair = (dark ? Color.white : Color.black).opacity(0.08)
    accentInk = Self.rgb(dark ? 0x17151F : 0xFFFFFF)
    surface = Self.rgb(dark ? 0x18181C : 0xF6F6F8).opacity(dark ? 0.72 : 0.78)
    solid = Self.rgb(dark ? 0x1F1F23 : 0xF6F6F8)
    primary = Self.rgb(dark ? 0xECECEE : 0x1C1C1F)
    secondary = Self.rgb(dark ? 0xA3A4AA : 0x55565C)
    typed = Self.rgb(dark ? 0x8A8B92 : 0x6B6C73)
    faint = Self.rgb(dark ? 0x5E5F66 : 0xA6A7AD)
    // Panel.dc.html oklch tokens converted once to sRGB, with gamut clipping.
    accent =
      dark
      ? Color(.sRGB, red: 0.699118, green: 0.587094, blue: 0.998841)
      : Color(.sRGB, red: 0.449172, green: 0.303086, blue: 0.746457)
    zone = accent.opacity(dark ? 0.2 : 0.14)
    key = (dark ? Color.white : Color.black).opacity(dark ? 0.07 : 0.06)
    error =
      dark
      ? Color(.sRGB, red: 0.992693, green: 0.451639, blue: 0.425769)
      : Color(.sRGB, red: 0.786912, green: 0.184, blue: 0.198880)
    settingsConflict =
      dark ? Color(.sRGB, red: 1, green: 0.583656, blue: 0.552349) : error
    cap = (dark ? Color.white : Color.black).opacity(dark ? 0.1 : 0.07)
    edge = Color.white.opacity(dark ? 0.16 : 0.7)
  }

  private static func rgb(_ hex: UInt32) -> Color {
    Color(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
  }
}
