import AppKit
import SwiftUI
import Testing
import TwiddleUI

struct SnapshotExport {
  @Test @MainActor func placeholder() throws {
    let renderer = ImageRenderer(content: PlaceholderPanelView())
    renderer.scale = 1
    let image = try #require(renderer.cgImage)
    #expect(image.width == 720)
    #expect(image.height == 136)

    if let directory = ProcessInfo.processInfo.environment["TWIDDLE_SNAPSHOT_DIR"] {
      let destination = URL(fileURLWithPath: directory, isDirectory: true)
      try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
      let bitmap = NSBitmapImageRep(cgImage: image)
      let png = try #require(bitmap.representation(using: .png, properties: [:]))
      try png.write(to: destination.appendingPathComponent("placeholder.png"))
    }
  }
}
