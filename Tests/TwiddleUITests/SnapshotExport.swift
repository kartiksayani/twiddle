import AppKit
import SwiftUI
import Testing
import TwiddleCore
import TwiddleUI

private enum Fixture: String, CaseIterable {
  case waiting, fixed, resumed, paused, code, codeGo, symbols, prose, weakKeys, weakFallback
  case sprintReady, sprintRunning, sprintResult, sprintGhost, sprintNewBest, capsule
  case hintsOff, hintsPlain, hintsCapital, hintsSymbol, progressData, progressEmpty, progressOne,
    intro
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
        if fixture == .codeGo {
          state.codePack = .go
          state.resume["code"] = Store.Resume(
            session: TypingSession(
              text: String(
                repeating: "if err := run(ctx); err != nil {\n    return err\n}\n", count: 30)))
        }
        state.resume["symbols"] = Store.Resume(
          session: TypingSession(
            text: String(repeating: "port: 8080\na[i] += 2;\n~/src/*.go\n", count: 30)))
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
        if [.hintsCapital].contains(fixture) {
          state.resume["prose"] = Store.Resume(
            session: TypingSession(
              text:
                "Two roads diverged in a wood, and I took the one less travelled by, and that has made all "
                + String(repeating: "the difference ", count: 60)))
        }
        if fixture == .hintsSymbol {
          state.resume["code"] = Store.Resume(
            session: TypingSession(
              text:
                "if err := run(ctx); err != nil {\n    return fmt.Errorf(\"sync: %w\", err)\n}\n"
                + String(repeating: "const value = await read();\n", count: 30)))
        }
        if fixture == .progressData || fixture == .progressOne {
          state.today = .init(
            date: store.today,
            counters: .init(
              netCorrectChars: 4180, presses: 4500, correctPresses: 4340,
              activeSeconds: 660), bestWPM: 91)
          let speeds =
            fixture == .progressOne
            ? [84]
            : [71, 74, 69, 76, 73, 78, 75, 80, 72, 77, 79, 74, 81, 76, 78, 91, 77, 80, 76, 84]
          state.runs = speeds.enumerated().map { index, speed in
            Store.Run(
              mode: .flow, source: .words,
              startedAt: Date(timeIntervalSince1970: 432000 + Double(index) * 3600),
              activeSeconds: 60, wpm: Double(speed), accuracy: 0.98, chars: speed * 5)
          }
          for (index, key) in ["q", "z", "[", "]", "-"].enumerated() {
            let milliseconds = [312, 298, 341, 336, 287][index]
            state.keys[key] = try JSONDecoder().decode(
              KeyStats.Entry.self,
              from: Data(
                "{\"samples\":20,\"averageMs\":\(milliseconds),\"errorRate\":\(index < 2 ? 0.4 : 0.1)}"
                  .utf8))
          }
        }
        if fixture == .sprintGhost || fixture == .sprintNewBest {
          state.bestSprintWPM = [30: fixture == .sprintGhost ? 100 : 60]
        }
        if fixture == .progressData {
          var rhythm = Rhythm()
          for index in 0..<40 { rhythm.record(index.isMultiple(of: 2) ? 0.23 : 0.27) }
          state.today.rhythm = rhythm
          for (index, pair) in ["th", "st", "ch", "ou", "gh"].enumerated() {
            state.pairs[pair] = try JSONDecoder().decode(
              KeyStats.Entry.self,
              from: Data("{\"samples\":10,\"averageMs\":\(380 - index * 17),\"errorRate\":0}".utf8))
          }
          state.keys["a"] = try JSONDecoder().decode(
            KeyStats.Entry.self,
            from: Data("{\"samples\":1000,\"averageMs\":132,\"errorRate\":0}".utf8))
        }
        if fixture == .progressOne {
          state.keys = state.keys.filter { ["q", "z"].contains($0.key) }
          state.pairs["th"] = try JSONDecoder().decode(
            KeyStats.Entry.self,
            from: Data("{\"samples\":10,\"averageMs\":245,\"errorRate\":0}".utf8))
        }
        if fixture == .progressEmpty { state.today = .init(date: store.today) }
        try store.save(state)
        var time = 0.0
        let model = PracticeModel(
          store: store, random: SnapshotRandom(), now: { time })
        if fixture == .intro { model.launch() } else { model.summon() }
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
        case .hintsOff, .hintsPlain:
          for _ in 0..<2 { model.handle(.character(model.session.expected!)) }
          if fixture == .hintsPlain { model.handle(.toggleHints) }
          #expect(model.hint?.key == "o")
        case .hintsCapital:
          model.handle(.source(.prose))
          model.handle(.toggleHints)
          #expect(model.hint?.label == "T")
        case .hintsSymbol:
          model.handle(.source(.code))
          for _ in 0..<13 { model.handle(.character(model.session.expected!)) }
          model.handle(.toggleHints)
          #expect(model.hint?.label == "(")
        case .progressData, .progressEmpty, .progressOne:
          model.handle(.progress)
          #expect(model.view == .progress)
          #expect(
            model.progress.points.count
              == (fixture == .progressEmpty ? 0 : fixture == .progressOne ? 1 : 20))
        case .intro:
          #expect(model.view == .intro)

        case .code: model.handle(.source(.code))
        case .codeGo:
          model.handle(.source(.code))
          #expect(model.codePack == .go)
          #expect(model.sourceLabel == "Code · Go")
        case .symbols:
          model.handle(.source(.symbols))
          #expect(model.source == .symbols)
          #expect(model.sourceLabel == "Symbols")
        case .prose: model.handle(.source(.prose))
        case .weakKeys, .weakFallback: model.handle(.source(.weakKeys))
        case .sprintReady, .sprintRunning, .sprintResult, .sprintGhost, .sprintNewBest:
          model.handle(.sprint)
          if fixture != .sprintReady {
            let running = fixture == .sprintRunning || fixture == .sprintGhost
            let count = running ? 86 : 210
            let errors = running ? [75] : [16, 57, 103]
            for index in 0..<count {
              time = 3 + Double(index) * 0.05
              if errors.contains(index) {
                model.handle(.character("!"))
                model.handle(.character("!"))
              }
              model.handle(.character(model.session.expected!))
            }
            time = running ? 15 : 33
            model.tick()
            if !running {
              time = 33.61
              model.tick()
              #expect(model.sprintState == .result)
              if fixture == .sprintNewBest { #expect(model.result?.isNewBest == true) }
            } else {
              #expect(model.sprintState == .running)
              #expect(model.sprintRemaining == 18)
              #expect(model.headerCounters.wpm == 86)
              if fixture == .sprintGhost { #expect(model.ghostOffset == 100) }
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
          model.panelHeight
          + (fixture == .capsule
            ? Theme.capsuleOffset + Theme.capsuleHeight : 0)
        #expect(image.height == Int(expectedHeight * 2))
        if ![
          Fixture.sprintRunning, .sprintResult, .sprintGhost, .sprintNewBest, .hintsOff,
          .hintsPlain, .hintsCapital, .hintsSymbol,
          .progressData, .progressEmpty, .progressOne,
        ].contains(fixture) {
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
