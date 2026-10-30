import AppKit
import SwiftUI
import Testing
import TwiddleCore
import TwiddleUI

private enum Fixture: String, CaseIterable {
  case waiting, fixed, resumed, paused, code, prose, weakKeys, weakFallback
  case sprintReady, sprintRunning, sprintResult, capsule
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
        state.resume["code"] = Store.Resume(
          session: TypingSession(
            text: "if err := run(ctx); err != nil {\n    return fmt.Errorf(\"sync: %w\", err)\n}\n"
              + String(repeating: "const value = await read();\n", count: 30), caret: 19,
            mistakes: []))
        state.resume["prose"] = Store.Resume(
          session: TypingSession(
            text:
              "The sun had set behind the hill, and the long road lay quiet in the evening light. "
              + String(repeating: "A little wind moved through the trees. ", count: 25), caret: 25,
            mistakes: []))
        if fixture == .weakKeys {
          for key in ["q", "z", "[", "]", "-"] {
            state.keys[key] = try JSONDecoder().decode(
              KeyStats.Entry.self,
              from: Data("{\"samples\":20,\"averageMs\":300,\"errorRate\":0.1}".utf8))
          }
        }
        try store.save(state)
        var time = 0.0
        let model = PracticeModel(
          store: store, random: SnapshotRandom(), now: { time })
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
        switch fixture {
        case .code: model.handle(.source(.code))
        case .prose: model.handle(.source(.prose))
        case .weakKeys, .weakFallback: model.handle(.source(.weakKeys))
        case .sprintReady, .sprintRunning, .sprintResult:
          model.handle(.sprint)
          if fixture != .sprintReady {
            let count = fixture == .sprintRunning ? 86 : 210
            let errors = fixture == .sprintRunning ? [75] : [16, 57, 103]
            for index in 0..<count {
              time = 3 + Double(index) * 0.05
              if errors.contains(index) {
                model.handle(.character("!"))
                model.handle(.character("!"))
              }
              model.handle(.character(model.session.expected!))
            }
            time = fixture == .sprintRunning ? 15 : 33
            model.tick()
            if fixture == .sprintResult {
              time = 33.61
              model.tick()
              #expect(model.sprintState == .result)
            } else {
              #expect(model.sprintState == .running)
              #expect(model.sprintRemaining == 18)
              #expect(model.headerCounters.wpm == 86)
            }
          } else {
            #expect(model.sprintState == .ready)
            #expect(model.headerCounters.presses == 0)
          }
        default: break
        }
        let content = VStack(spacing: Theme.capsuleOffset) {
          if fixture == .capsule { CommandCapsuleView(model: model, snapshot: true) }
          PanelView(model: model, snapshot: true)
        }
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == Int(Theme.panelSize.width * 2))
        let expectedHeight =
          Theme.panelSize.height
          + (fixture == .capsule
            ? Theme.capsuleOffset + Theme.capsuleHeight : 0)
        #expect(image.height == Int(expectedHeight * 2))
        if ![Fixture.sprintRunning, .sprintResult].contains(fixture) {
          #expect(model.stats.today.wpm == 78)
          #expect(model.stats.today.accuracy == 0.964)
        }
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

}

private struct SnapshotRandom: RandomNumberGenerator {
  private var state: UInt64 = 42

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    return state
  }
}
