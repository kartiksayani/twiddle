import Foundation
import Testing
import TwiddleCore

struct ProgressDataTests {
  @Test func readsTodayAndSavedRankedKeysAndNewestTwentyRuns() throws {
    var state = Store.State(date: "2026-10-31")
    state.today = Store.Today(
      date: state.today.date,
      counters: .init(netCorrectChars: 4180, activeSeconds: 660), bestWPM: 91)
    for (index, key) in ["a", "b", "c", "d", "e", "f"].enumerated() {
      state.keys[key] = try JSONDecoder().decode(
        KeyStats.Entry.self,
        from: Data("{\"samples\":20,\"averageMs\":\(300 + index),\"errorRate\":0.1}".utf8))
    }
    state.runs = (0..<25).reversed().map { index in
      Store.Run(
        mode: .flow, source: .words, startedAt: Date(timeIntervalSince1970: Double(index)),
        activeSeconds: 60, wpm: Double(index + 60), accuracy: 1, chars: 300)
    }
    let data = ProgressData(state: state)
    #expect(data.minutes == 11)
    #expect(data.average == 76)
    #expect(data.best == 91)
    #expect(data.weakestKeys.map(\.key) == Array("fedcb"))
    #expect(data.weakestKeys.map(\.stats.averageMs) == [305, 304, 303, 302, 301])
    #expect(data.runs.count == 20)
    #expect(data.runs.first?.startedAt == Date(timeIntervalSince1970: 5))
    #expect(data.oldestDate == data.runs.first?.startedAt)
    #expect(data.runs.last?.startedAt == Date(timeIntervalSince1970: 24))
    #expect(data.points.first?.x == 0)
    #expect(data.points.last?.x == 1)
    #expect(data.bestPoint == data.points.last)
    #expect(!data.isEmpty)
  }

  @Test func flatZeroHistoryAndEqualBestUseFiniteCoordinates() {
    var state = Store.State(date: "2026-10-31")
    state.runs = (0..<2).map { index in
      Store.Run(
        mode: .sprint, source: .words, startedAt: Date(timeIntervalSince1970: Double(index)),
        activeSeconds: 30, wpm: 0, accuracy: 0, chars: 0)
    }
    let data = ProgressData(state: state)
    #expect(data.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    #expect(data.bestPoint == data.points.first)
  }

  @Test func boardTrendUsesBoardScale() {
    var state = Store.State(date: "2026-10-31")
    state.today = .init(
      date: state.today.date, counters: .init(netCorrectChars: 380, activeSeconds: 60))
    let speeds = [71, 74, 69, 76, 73, 78, 75, 80, 72, 77, 79, 74, 81, 76, 78, 91, 77, 80, 76, 84]
    state.runs = speeds.enumerated().map { index, speed in
      Store.Run(
        mode: .flow, source: .words, startedAt: Date(timeIntervalSince1970: Double(index)),
        activeSeconds: 60, wpm: Double(speed), accuracy: 1, chars: speed * 5)
    }
    let data = ProgressData(state: state)
    #expect(abs(data.averageY - 0.6) < 0.00001)
    #expect(abs(data.points[15].y - 0.1) < 0.00001)
    #expect(data.bestPoint == data.points[15])
  }
}

struct PanelLayoutTests {
  @Test func heightsMatchBoard() {
    #expect(PanelLayout.height(view: .text, hints: false) == 136)
    #expect(PanelLayout.height(view: .text, hints: true) == 252)
    #expect(PanelLayout.height(view: .progress, hints: false) == 185)
    #expect(PanelLayout.height(view: .intro, hints: false) == 136)
  }

  @Test(arguments: [136.0, 252, 185, 136])
  func resizingKeepsBottom(height: Double) {
    let frame = PanelLayout.clamp(
      .init(x: 200, y: 60, width: 720, height: height),
      to: .init(x: 0, y: 20, width: 1200, height: 800))
    #expect(frame.y == 60)
    #expect(frame.x == 200)
    #expect(frame.height == height)
  }

  @Test func clampsTopAndSidesToScreenIncludingNegativeScreenOrigin() {
    let visible = PanelLayout.Rect(x: -1200, y: 20, width: 1200, height: 600)
    let frame = PanelLayout.clamp(
      .init(x: -400, y: 500, width: 720, height: 252), to: visible)
    #expect(frame == .init(x: -720, y: 368, width: 720, height: 252))
    let lower = PanelLayout.clamp(
      .init(x: -1300, y: 0, width: 720, height: 136), to: visible)
    #expect(lower.x == -1200)
    #expect(lower.y == 20)
  }
}
