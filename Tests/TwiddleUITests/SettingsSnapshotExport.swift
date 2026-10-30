import AppKit
import SwiftUI
import Testing
import TwiddleCore
import TwiddleUI

struct SettingsSnapshotExport {
  @Test @MainActor func settings() throws {
    for scheme in [ColorScheme.dark, .light] {
      for fixture in ["settings", "recording", "conflict", "cleared"] {
        let name = "TwiddleSnapshots.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = TwiddleCore.Settings(defaults: defaults)
        settings.theme = scheme == .dark ? .dark : .light
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
          UUID().uuidString)
        defer {
          if FileManager.default.fileExists(atPath: directory.path) {
            try! FileManager.default.removeItem(at: directory)
          }
        }
        let model = PracticeModel(
          store: Store(directory: directory, currentDate: { Date(timeIntervalSince1970: 0) }),
          random: SettingsRandom(), settings: settings)
        let recorder = HotkeyRecorder(settings: settings) { _ in fixture != "conflict" }
        if fixture == "recording" { recorder.begin() }
        if fixture == "conflict" {
          recorder.begin()
          recorder.capture(keyCode: 49, modifiers: .option)
        }
        if fixture == "cleared" { recorder.clear() }
        let login = LoginSetting(read: { true }, update: { _ in })
        let form = SettingsForm(settings: settings, model: model, recorder: recorder, login: login)
          .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: form)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == 1000)
        #expect(image.height == 936)
        if let output = ProcessInfo.processInfo.environment["TWIDDLE_SNAPSHOT_DIR"] {
          let destination = URL(fileURLWithPath: output, isDirectory: true)
          try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)
          let png = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
          try png.write(
            to: destination.appendingPathComponent(
              "\(fixture)-\(scheme == .dark ? "dark" : "light").png"))
        }
      }
    }
  }
}

private struct SettingsRandom: RandomNumberGenerator {
  mutating func next() -> UInt64 { 42 }
}
