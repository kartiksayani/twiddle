import AppKit
import ImageIO
import SwiftUI
import Testing
import TwiddleCore
import TwiddleUI
import UniformTypeIdentifiers

struct ReadmeScreenshots {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["TWIDDLE_SCREENSHOT_DIR"] != nil))
  @MainActor func compose() throws {
    let output = try #require(ProcessInfo.processInfo.environment["TWIDDLE_SCREENSHOT_DIR"])
    let destination = URL(fileURLWithPath: output, isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let snapshots = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent(".build/snapshots", isDirectory: true)

    for (name, fixture) in [
      ("flow", "waiting"), ("code", "code"), ("sprint", "sprintResult"),
      ("hints", "hintsPlain"), ("progress", "progressData"), ("commands", "capsule"),
      ("symbols", "symbols"), ("ghost", "sprintGhost"),
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
    try demo(to: destination.appendingPathComponent("demo.gif"))
  }

  @MainActor private func demo(to url: URL) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try! FileManager.default.removeItem(at: directory) }
    let date = Date(timeIntervalSince1970: 0)
    let store = Store(directory: directory, currentDate: { date })
    var state = Store.State(date: store.today)
    state.today = .init(
      date: store.today,
      counters: .init(netCorrectChars: 100, presses: 100, correctPresses: 100, activeSeconds: 15))
    state.resume["words"] = .init(
      session: TypingSession(
        text: String(
          repeating: "there might still think about small early because around another people ",
          count: 12)))
    try store.save(state)
    // Let the resume note expire before the storyboard starts.
    var time = -3.0
    let model = PracticeModel(store: store, random: DemoRandom(), now: { time }, date: { date })
    model.summon()

    var random = DemoRandom()
    var events: [(time: Double, input: TypingSession.Input)] = []
    let text = Array(model.session.text)
    var next = 1.10
    var offset = 0
    while next < 8.85 {
      if offset == 32 {
        events.append((next, .character("q")))
        events.append((next + 0.36, .backspace))
        next += 0.46
      }
      events.append((next, .character(text[offset])))
      next += 0.12 + Double(random.next() % 61) / 1000
      offset += 1
    }

    // Centisecond boundaries alternate 80/90 ms delays without accumulating GIF rounding drift.
    let boundaries = (0...132).map { (Double($0) / 12 * 100).rounded() / 100 }
    let frameCount = boundaries.count - 1
    let finishedAt = 9.0
    let pillAt = finishedAt + 0.08
    let hideAt = pillAt + Theme.summonDuration + 1.5
    let data = NSMutableData()
    let encoder = try #require(
      CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, frameCount, nil))
    CGImageDestinationSetProperties(
      encoder, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    var eventIndex = 0
    var sawPending = false
    var sawCorrection = false
    for frame in 0..<frameCount {
      let frameTime = boundaries[frame]
      while eventIndex < events.count && events[eventIndex].time <= frameTime {
        time = events[eventIndex].time
        model.handle(events[eventIndex].input)
        eventIndex += 1
      }
      time = frameTime
      model.tick()
      if model.session.pending != nil { sawPending = true }
      if sawPending && model.session.pending == nil && model.session.caret > 32 {
        sawCorrection = true
      }
      try autoreleasepool {
        let panelRenderer = ImageRenderer(
          content: PanelView(model: model, snapshot: true).environment(\.colorScheme, .dark))
        panelRenderer.scale = 2
        let panel = try #require(panelRenderer.cgImage)
        let summon = min(1, max(0, (frameTime - 0.75) / Theme.summonDuration))
        let eased = UnitCurve.easeOut.value(at: summon)
        let pill = min(1, max(0, (frameTime - pillAt) / Theme.summonDuration))
        let fade = min(1, max(0, (frameTime - hideAt) / Theme.hideDuration))
        let scene = DesktopScene(
          panel: panel, scheme: .dark, panelOpacity: eased * (1 - fade),
          panelRise: Theme.summonRise * (1 - eased), pillOpacity: pill * (1 - fade),
          elapsed: 134 + Int(min(frameTime, finishedAt) + 0.5), finished: frameTime >= finishedAt)
        let image = try render(scene, size: CGSize(width: 1440, height: 900), scale: 800.0 / 1440)
        let delay = ((boundaries[frame + 1] - frameTime) * 100).rounded() / 100
        CGImageDestinationAddImage(
          encoder, image,
          [
            kCGImagePropertyGIFDictionary: [
              kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
            ]
          ] as CFDictionary)
      }
    }
    #expect(eventIndex == events.count)
    #expect(model.session.caret == offset)
    #expect(model.session.mistakes == [32])
    #expect(sawPending && sawCorrection)
    #expect((75...85).contains(model.headerCounters.wpm))
    #expect(CGImageDestinationFinalize(encoder))
    #expect(data.length < 5_000_000)
    try (data as Data).write(to: url)

    let source = try #require(CGImageSourceCreateWithData(data, nil))
    #expect(CGImageSourceGetCount(source) == frameCount)
    var duration = 0.0
    for frame in 0..<frameCount {
      let properties = try #require(
        CGImageSourceCopyPropertiesAtIndex(source, frame, nil) as? [CFString: Any])
      #expect(properties[kCGImagePropertyPixelWidth] as? Int == 800)
      #expect(properties[kCGImagePropertyPixelHeight] as? Int == 500)
      let gif = try #require(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
      duration += try #require(gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
    }
    #expect(abs(duration - 11) < 0.001)
    #expect(duration < 12)
    let properties = try #require(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
    let gif = try #require(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
    #expect(gif[kCGImagePropertyGIFLoopCount] as? Int == 0)
  }

  @MainActor private func load(_ name: String, from directory: URL) throws -> CGImage {
    let data = try Data(contentsOf: directory.appendingPathComponent("\(name).png"))
    return try #require(NSBitmapImageRep(data: data)?.cgImage)
  }

  @MainActor private func export(
    _ content: some View, size: CGSize, scale: CGFloat, to url: URL
  ) throws {
    let image = try render(content, size: size, scale: scale)
    let png = try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    #expect(png.count < 1_000_000)
    try png.write(to: url)
  }

  @MainActor private func render(
    _ content: some View, size: CGSize, scale: CGFloat
  ) throws -> CGImage {
    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
    renderer.scale = scale
    renderer.isOpaque = true
    let image = try #require(renderer.cgImage)
    #expect(image.width == Int((size.width * scale).rounded()))
    #expect(image.height == Int((size.height * scale).rounded()))
    return image
  }
}

private struct DemoRandom: RandomNumberGenerator {
  private var state: UInt64 = 42

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    return state
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
  var panelOpacity = 1.0
  var panelRise = 0.0
  var pillOpacity = 0.0
  var elapsed = 134
  var finished = false

  var body: some View {
    ZStack(alignment: .topLeading) {
      DesktopWallpaper(scheme: scheme)
      DesktopMenuBar(scheme: scheme)
        .frame(width: 1440, height: 28)
      AgentTerminal(scheme: scheme, elapsed: elapsed, finished: finished)
        .frame(width: 1080, height: 570)
        .position(x: 720, y: 395)
      SnapshotPanel(image: panel)
        .opacity(panelOpacity)
        .position(x: 720, y: 732 + panelRise)
      FinishedPillView(snapshot: true)
        .opacity(pillOpacity)
        .position(
          x: 720,
          y: 732 + panelRise - CGFloat(panel.height) / 4
            - Theme.capsuleOffset - Theme.finishedHeight / 2)
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
  var elapsed = 134
  var finished = false

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
          if finished {
            Text("✓").foregroundStyle(theme.accent)
            Text("Done in \(elapsed / 60)m \(elapsed % 60)s").foregroundStyle(theme.primary)
          } else {
            Image(systemName: "circle.dotted").foregroundStyle(theme.accent)
            Text("Thinking…").foregroundStyle(theme.primary)
            Text("\(elapsed / 60)m \(elapsed % 60)s").foregroundStyle(theme.secondary)
          }
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
