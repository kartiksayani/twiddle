import AppKit
import SwiftUI
import Testing
import TwiddleCore
import TwiddleUI

private enum Fixture: String, CaseIterable {
  case waiting, fixed, resumed, paused, code
}

struct SnapshotExport {
  @Test @MainActor func panels() throws {
    let text = "there might still think about small early because around another people"
    for scheme in [ColorScheme.dark, .light] {
      for fixture in Fixture.allCases {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
          UUID().uuidString)
        defer { try! FileManager.default.removeItem(at: directory) }
        let store = Store(directory: directory, currentDate: { Date(timeIntervalSince1970: 0) })
        let correct = fixture == .waiting ? 8 : fixture == .fixed ? 9 : fixture == .paused ? 1 : 0
        let wrong = fixture == .waiting || fixture == .fixed ? 1 : 0
        var state = Store.State(date: store.today)
        state.today = Store.Today(
          date: store.today,
          counters: .init(
            netCorrectChars: 1950 - correct, presses: 2500 - correct - wrong,
            correctPresses: 2410 - correct, activeSeconds: 300))
        state.resume["words"] = Store.Resume(
          session: TypingSession(
            text: text + String(repeating: " ", count: 46)
              + String(repeating: "words ", count: 100),
            caret: fixture == .resumed ? 26 : 24, mistakes: [16]))
        try store.save(state)
        var time = 0.0
        let model = PracticeModel(
          store: store, random: SystemRandomNumberGenerator(), now: { time })
        model.summon()
        for _ in 0..<(correct - (fixture == .fixed ? 1 : 0)) {
          model.handle(.character(model.session.expected!))
        }
        if wrong > 0 {
          // Recreate the board's waiting q on the a in small, then its corrected state.
          if fixture == .fixed {
            model.handle(.character("q"))
            model.handle(.character(model.session.expected!))
          } else {
            model.handle(.character("q"))
          }
        }
        time = fixture == .paused ? 10 : fixture == .resumed ? 0 : 3
        model.tick()
        let content = Group {
          if fixture == .code {
            codePanel(counters: model.stats.today, scheme: scheme)
          } else {
            PanelView(model: model, snapshot: true)
          }
        }
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == Int(Theme.panelSize.width * 2))
        #expect(image.height == Int(Theme.panelSize.height * 2))
        #expect(model.stats.today.wpm == 78)
        #expect(model.stats.today.accuracy == 0.964)
        if let output = ProcessInfo.processInfo.environment["TWIDDLE_SNAPSHOT_DIR"] {
          let destination = URL(fileURLWithPath: output, isDirectory: true)
          try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)
          let bitmap = NSBitmapImageRep(cgImage: image)
          let png = try #require(bitmap.representation(using: .png, properties: [:]))
          let name = "\(fixture.rawValue)-\(scheme == .dark ? "dark" : "light").png"
          try png.write(to: destination.appendingPathComponent(name))
        }
      }
    }
  }

  @MainActor private func codePanel(counters: StatsTracker.Counters, scheme: ColorScheme)
    -> some View
  {
    let text = "if err := run(ctx); err != nil {\n    return fmt.Errorf(\"sync: %w\", err)\n}"
    let session = TypingSession(text: text, caret: 3, mistakes: [])
    let theme = Theme(scheme)
    return VStack(spacing: 0) {
      HeaderView(counters: counters, resumedWord: nil, paused: false, source: "Code")
      PracticeTextView(
        session: session, characters: Array(text), lines: TextLayout.layout(text),
        blinks: false)
    }
    .frame(width: Theme.panelSize.width, height: Theme.panelSize.height)
    .background(theme.solid)
    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    .overlay(
      RoundedRectangle(cornerRadius: Theme.radius)
        .strokeBorder(theme.edge, lineWidth: Theme.edgeWidth))
  }
}
