import AppKit
import SwiftUI
import Testing
import TwiddleUI

struct ReadmeScreenshots {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["TWIDDLE_SCREENSHOT_DIR"] != nil))
  @MainActor func compose() throws {
    let output = try #require(ProcessInfo.processInfo.environment["TWIDDLE_SCREENSHOT_DIR"])
    let destination = URL(fileURLWithPath: output, isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let snapshots = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/snapshots", isDirectory: true)

    for scheme in [ColorScheme.dark, .light] {
      let name = scheme == .dark ? "dark" : "light"
      let panel = try load("waiting-\(name)", from: snapshots)
      try export(
        DesktopScene(panel: panel, scheme: scheme), size: CGSize(width: 1440, height: 900),
        scale: 1600.0 / 1440, to: destination.appendingPathComponent("hero-\(name).png"))
    }

    for (name, fixture) in [
      ("flow", "waiting"), ("code", "code"), ("sprint", "sprintResult"),
      ("hints", "hintsPlain"), ("progress", "progressData"), ("commands", "capsule"),
    ] {
      let panel = try load("\(fixture)-dark", from: snapshots)
      // Multiples of three keep the 4/3 export scale on whole pixels.
      let height = max(360, ceil((CGFloat(panel.height) / 2 + 192) / 3) * 3)
      let content = ZStack {
        DesktopWallpaper(scheme: .dark)
        SnapshotPanel(image: panel)
      }
      try export(
        content, size: CGSize(width: 900, height: height), scale: 4.0 / 3,
        to: destination.appendingPathComponent("\(name).png"))
    }
  }

  @MainActor private func load(_ name: String, from directory: URL) throws -> CGImage {
    let data = try Data(contentsOf: directory.appendingPathComponent("\(name).png"))
    return try #require(NSBitmapImageRep(data: data)?.cgImage)
  }

  @MainActor private func export(
    _ content: some View, size: CGSize, scale: CGFloat, to url: URL
  ) throws {
    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
    renderer.scale = scale
    renderer.isOpaque = true
    let image = try #require(renderer.cgImage)
    #expect(image.width == Int((size.width * scale).rounded()))
    #expect(image.height == Int((size.height * scale).rounded()))
    let png = try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    #expect(png.count < 1_000_000)
    try png.write(to: url)
  }
}

private struct SnapshotPanel: View {
  let image: CGImage

  var body: some View {
    Image(decorative: image, scale: 2)
      .resizable()
      .interpolation(.high)
      .frame(width: Theme.panelSize.width, height: CGFloat(image.height) / 2)
      .shadow(color: .black.opacity(0.3), radius: 26, y: 16)
      .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
  }
}

private struct DesktopWallpaper: View {
  let scheme: ColorScheme

  private var dark: Bool { scheme == .dark }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      ZStack {
        LinearGradient(
          colors: dark
            ? [Color(red: 0.08, green: 0.12, blue: 0.23), Color(red: 0.23, green: 0.2, blue: 0.38)]
            : [
              Color(red: 0.67, green: 0.75, blue: 0.87), Color(red: 0.87, green: 0.79, blue: 0.88),
            ],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        RadialGradient(
          colors: [Theme(.dark).accent.opacity(dark ? 0.45 : 0.36), .clear],
          center: UnitPoint(x: 0.82, y: 0.12), startRadius: 0, endRadius: size.width * 0.7)
        Path { path in
          path.move(to: CGPoint(x: 0, y: size.height * 0.52))
          path.addCurve(
            to: CGPoint(x: size.width, y: size.height * 0.3),
            control1: CGPoint(x: size.width * 0.42, y: size.height * 1.15),
            control2: CGPoint(x: size.width * 0.68, y: -size.height * 0.18))
          path.addLine(to: CGPoint(x: size.width, y: size.height))
          path.addLine(to: CGPoint(x: 0, y: size.height))
          path.closeSubpath()
        }
        .fill(
          LinearGradient(
            colors: dark
              ? [Color(red: 0.4, green: 0.39, blue: 0.62), Color(red: 0.2, green: 0.23, blue: 0.4)]
              : [
                Color(red: 0.89, green: 0.85, blue: 0.94), Color(red: 0.55, green: 0.61, blue: 0.8),
              ],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        RadialGradient(
          colors: [Theme(.dark).accent.opacity(dark ? 0.25 : 0.12), .clear],
          center: .bottomLeading, startRadius: 0, endRadius: size.width * 0.65)
      }
    }
  }
}

private struct DesktopScene: View {
  let panel: CGImage
  let scheme: ColorScheme

  var body: some View {
    ZStack(alignment: .topLeading) {
      DesktopWallpaper(scheme: scheme)
      DesktopMenuBar(scheme: scheme)
        .frame(width: 1440, height: 28)
      AgentTerminal(scheme: scheme)
        .frame(width: 1080, height: 570)
        .position(x: 720, y: 395)
      SnapshotPanel(image: panel)
        .position(x: 720, y: 732)
    }
    .environment(\.colorScheme, scheme)
  }
}

private struct DesktopMenuBar: View {
  let scheme: ColorScheme

  var body: some View {
    HStack(spacing: 22) {
      Image(systemName: "apple.logo")
      Text("Terminal").fontWeight(.semibold)
      ForEach(["Shell", "Edit", "View", "Window", "Help"], id: \.self) { Text($0) }
      Spacer()
      RoundedRectangle(cornerRadius: Theme.statusIconRadius)
        .stroke(lineWidth: Theme.statusIconStroke)
        .frame(width: 15, height: 11)
        .overlay(alignment: .leading) {
          Rectangle().frame(width: 1.5, height: 5).padding(.leading, 4)
        }
      Image(systemName: "wifi")
      Image(systemName: "battery.100percent")
      Text("Mon 9:41")
    }
    .font(.system(size: 13))
    .foregroundStyle(Theme(scheme).primary)
    .padding(.horizontal, 22)
    .frame(maxHeight: .infinity)
    .background(Theme(scheme).solid.opacity(0.35))
    .overlay(alignment: .bottom) { Theme(scheme).hair.frame(height: 0.5) }
  }
}

private struct AgentTerminal: View {
  let scheme: ColorScheme

  private var theme: Theme { Theme(scheme) }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        ForEach([Color(red: 1, green: 0.37, blue: 0.34), .yellow, .green], id: \.self) { color in
          Circle().fill(color.opacity(0.85)).frame(width: 12, height: 12)
        }
        Spacer()
      }
      .padding(.horizontal, 16)
      .frame(height: 42)
      .overlay { Text("workspace — agent").font(.system(size: 13, weight: .medium)) }
      .background(theme.key)
      theme.hair.frame(height: 0.5)
      VStack(alignment: .leading, spacing: 22) {
        Text("❯ agent").foregroundStyle(theme.secondary)
        Text("Add keyboard navigation to the command palette.")
          .foregroundStyle(theme.primary)
        VStack(alignment: .leading, spacing: 12) {
          terminalLine("Read", "3 files · palette, shortcuts, tests")
          terminalLine("Plan", "Keep selection visible as the results change")
          terminalLine("Edit", "Wire arrow keys, return, and escape")
        }
        .padding(.vertical, 8)
        Text("Checking focus handling and the edge cases…")
          .foregroundStyle(theme.secondary)
        HStack(spacing: 10) {
          Image(systemName: "circle.dotted").foregroundStyle(theme.accent)
          Text("Thinking…").foregroundStyle(theme.primary)
          Text("2m 14s").foregroundStyle(theme.secondary)
        }
        Spacer(minLength: 0)
      }
      .font(.system(size: 16, design: .monospaced))
      .padding(30)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .foregroundStyle(theme.secondary)
    .background(theme.solid)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(theme.edge, lineWidth: 0.75) }
    .shadow(color: .black.opacity(0.2), radius: 30, y: 18)
  }

  private func terminalLine(_ action: String, _ detail: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 18) {
      Text("✓").foregroundStyle(theme.accent)
      Text(action).foregroundStyle(theme.primary).frame(width: 44, alignment: .leading)
      Text(detail).foregroundStyle(theme.secondary)
    }
  }
}
