import AppKit
import SwiftUI
import TwiddleCore
import TwiddleUI

@MainActor
private final class TwiddlePanel: NSPanel {
  var onEscape: (() -> Void)?

  override var canBecomeKey: Bool { true }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      onEscape?()
    } else {
      super.keyDown(with: event)
    }
  }

  override func cancelOperation(_ sender: Any?) {
    onEscape?()
  }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
  private var presence = PanelPresence()
  private var mouseMonitor: Any?
  private let panel: TwiddlePanel

  override init() {
    panel = TwiddlePanel(
      contentRect: NSRect(origin: .zero, size: PlaceholderPanelView.size),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    super.init()
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.contentView = NSHostingView(rootView: PlaceholderPanelView())
    panel.delegate = self
    panel.onEscape = { [weak self] in self?.handle(.escape) }
  }

  func handle(_ event: PanelPresence.Event) {
    switch presence.handle(event) {
    case .show:
      show()
    case .hide:
      if let mouseMonitor {
        NSEvent.removeMonitor(mouseMonitor)
        self.mouseMonitor = nil
      }
      panel.orderOut(nil)
    case nil:
      break
    }
  }

  func windowDidResignKey(_ notification: Notification) {
    handle(.resignKey)
  }

  private func show() {
    let mouse = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
      let visible = screen.visibleFrame
      panel.setFrameOrigin(
        NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.minY + 40)
      )
    }
    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
      // AppKit delivers event monitors on the main thread.
      MainActor.assumeIsolated {
        self?.handle(.outsideMouseDown)
      }
    }
    panel.makeKeyAndOrderFront(nil)
  }
}
