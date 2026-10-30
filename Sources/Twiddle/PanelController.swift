import AppKit
import QuartzCore
import SwiftUI
import TwiddleCore
import TwiddleUI

@MainActor
private final class TwiddlePanel: NSPanel {
  var router: KeyRouter?

  override var canBecomeKey: Bool { true }

  override func keyDown(with event: NSEvent) { router?.route(event) }
  override func flagsChanged(with event: NSEvent) { router?.route(event) }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard event.modifierFlags.contains(.command) else { return false }
    router?.route(event)
    return true
  }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
  private var presence = PanelPresence()
  private var mouseMonitor: Any?
  private var timer: Timer?
  private var motion = 0
  private let capsulePanel: NSPanel
  private let panel: TwiddlePanel
  private let model: PracticeModel

  init(model: PracticeModel) {
    self.model = model
    panel = TwiddlePanel(
      contentRect: NSRect(origin: .zero, size: Theme.panelSize),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    capsulePanel = NSPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    super.init()
    capsulePanel.isOpaque = false
    capsulePanel.backgroundColor = .clear
    capsulePanel.ignoresMouseEvents = true
    capsulePanel.hasShadow = true
    capsulePanel.hidesOnDeactivate = false
    capsulePanel.isReleasedWhenClosed = false
    let capsuleView = NSHostingView(rootView: CommandCapsuleView(model: model))
    let capsuleSize = capsuleView.fittingSize
    let capsuleMaterial = NSVisualEffectView(frame: NSRect(origin: .zero, size: capsuleSize))
    capsuleMaterial.material = .hudWindow
    capsuleMaterial.blendingMode = .behindWindow
    capsuleMaterial.state = .active
    capsuleMaterial.maskImage = NSImage(size: capsuleSize, flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: Theme.capsuleRadius, yRadius: Theme.capsuleRadius)
        .fill()
      return true
    }
    capsuleView.frame = capsuleMaterial.bounds
    capsuleView.autoresizingMask = [.width, .height]
    capsuleMaterial.addSubview(capsuleView)
    capsulePanel.contentView = capsuleMaterial
    capsulePanel.setContentSize(capsuleSize)
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: Theme.panelSize))
    material.material = .hudWindow
    material.blendingMode = .behindWindow
    material.state = .active
    material.maskImage = NSImage(size: Theme.panelSize, flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: Theme.radius, yRadius: Theme.radius).fill()
      return true
    }
    let hosting = NSHostingView(rootView: PanelView(model: model))
    hosting.frame = material.bounds
    hosting.autoresizingMask = [.width, .height]
    material.addSubview(hosting)
    panel.contentView = material
    panel.delegate = self
    panel.router = KeyRouter(
      model: model, hide: { [weak self] in self?.handle(.escape) },
      capsuleChanged: { [weak self] visible in self?.showCapsule(visible) })
  }

  func handle(_ event: PanelPresence.Event) {
    switch presence.handle(event) {
    case .show:
      show()
    case .hide:
      hide()
    case nil:
      break
    }
  }

  func quit() {
    timer?.invalidate()
    panel.router?.dismissCapsule()
    model.quit()
  }

  func windowDidResignKey(_ notification: Notification) { handle(.resignKey) }

  private func showCapsule(_ visible: Bool) {
    if visible {
      guard !capsulePanel.isVisible else { return }
      capsulePanel.setFrameOrigin(
        NSPoint(
          x: panel.frame.midX - capsulePanel.frame.width / 2,
          y: panel.frame.maxY + Theme.capsuleOffset))
      panel.addChildWindow(capsulePanel, ordered: .above)
      capsulePanel.orderFront(nil)
    } else {
      panel.removeChildWindow(capsulePanel)
      capsulePanel.orderOut(nil)
    }
  }

  private func hide() {
    panel.router?.dismissCapsule()
    model.hide()
    timer?.invalidate()
    timer = nil
    if let mouseMonitor {
      NSEvent.removeMonitor(mouseMonitor)
      self.mouseMonitor = nil
    }
    motion += 1
    let generation = motion
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Theme.hideDuration
      panel.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.motion == generation else { return }
        self.panel.orderOut(nil)
      }
    }
  }

  private func show() {
    motion += 1
    model.summon()
    let mouse = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
      let visible = screen.visibleFrame
      panel.setFrameOrigin(
        NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.minY + Theme.bottomOffset)
      )
    }
    let destination = panel.frame
    panel.setFrameOrigin(NSPoint(x: destination.minX, y: destination.minY - Theme.summonRise))
    panel.alphaValue = 0
    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
      // AppKit delivers event monitors on the main thread.
      MainActor.assumeIsolated { self?.handle(.outsideMouseDown) }
    }
    timer = Timer.scheduledTimer(withTimeInterval: Theme.clockTick, repeats: true) {
      [weak self] _ in
      MainActor.assumeIsolated {
        self?.model.tick()
        self?.panel.router?.tick()
      }
    }
    panel.makeKeyAndOrderFront(nil)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Theme.summonDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().setFrame(destination, display: true)
      panel.animator().alphaValue = 1
    }
  }
}
