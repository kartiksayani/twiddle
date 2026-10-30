import SwiftUI

public struct Theme {
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

  public init(_ scheme: ColorScheme) {
    let dark = scheme == .dark
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
    error =
      dark
      ? Color(.sRGB, red: 0.992693, green: 0.451639, blue: 0.425769)
      : Color(.sRGB, red: 0.786912, green: 0.184, blue: 0.198880)
    cap = (dark ? Color.white : Color.black).opacity(dark ? 0.1 : 0.07)
    edge = Color.white.opacity(dark ? 0.16 : 0.7)
  }

  private static func rgb(_ hex: UInt32) -> Color {
    Color(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
  }
}
