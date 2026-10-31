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
private final class HeaderDragView: NSView {
  var begin: () -> Void = {}
  var move: (NSPoint) -> Void = { _ in }
  var finish: () -> Void = {}
  var reset: () -> Void = {}
  private var start: NSPoint?

  override func mouseDown(with event: NSEvent) {
    if event.clickCount == 2 {
      reset()
      return
    }
    start = NSEvent.mouseLocation
    begin()
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start else { return }
    let mouse = NSEvent.mouseLocation
    move(NSPoint(x: mouse.x - start.x, y: mouse.y - start.y))
  }

  override func mouseUp(with event: NSEvent) {
    guard start != nil else { return }
    start = nil
    finish()
  }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
  private var presence = PanelPresence()
  private var mouseMonitor: Any?
  private var timer: Timer?
  private var motion = 0
  private var capsuleMotion = 0
  private var capsuleContent: PracticeModel.CapsuleContent?
  private let capsulePanel: NSPanel
  private let panel: TwiddlePanel
  private let model: PracticeModel
  private var dragOrigin = NSPoint.zero
  var openSettings: () -> Void = {} {
    didSet { panel.router?.openSettings = openSettings }
  }

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
    material.updateMask(size: Theme.panelSize)
    let hosting = NSHostingView(rootView: PanelView(model: model))
    hosting.frame = material.bounds
    hosting.autoresizingMask = [.width, .height]
    material.addSubview(hosting)
    let header = HeaderDragView(
      frame: NSRect(
        x: 0, y: Theme.panelSize.height - Theme.headerHeight,
        width: Theme.panelSize.width, height: Theme.headerHeight))
    header.autoresizingMask = [.width, .minYMargin]
    header.begin = { [weak self] in
      guard let self else { return }
      self.dragOrigin = self.panel.frame.origin
    }
    header.move = { [weak self] delta in self?.drag(by: delta) }
    header.finish = { [weak self] in self?.saveOffset() }
    header.reset = { [weak self] in self?.resetPosition() }
    material.addSubview(header)
    panel.contentView = material
    panel.delegate = self
    panel.router = KeyRouter(
      model: model, hide: { [weak self] in self?.handle(.escape) },
      layoutChanged: { [weak self] in
        self?.resize()
        self?.refreshCapsule()
      })
  }

  func launch() {
    model.launch()
    if model.isVisible { handle(.hotkey) }
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
    model.quit()
    refreshCapsule()
  }

  func open(_ url: URL) {
    model.handle(url)
    refreshCapsule()
  }

  func practise() {
    if presence.state == .hidden { handle(.hotkey) }
  }

  func openProgress() {
    handle(.escape)
    model.openProgress()
    handle(.hotkey)
  }

  func windowDidResignKey(_ notification: Notification) { handle(.resignKey) }

  @ViewBuilder
  private func capsuleView(_ content: PracticeModel.CapsuleContent) -> some View {
    switch content {
    case .commands: CommandCapsuleView(model: model)
    case .finished: FinishedPillView()
    }
  }

  private func refreshCapsule() {
    let content = model.capsuleContent
    guard content != capsuleContent else { return }
    capsuleContent = content
    capsuleMotion += 1
    let generation = capsuleMotion
    if let content {
      let hosting = NSHostingView(rootView: capsuleView(content))
      let size = hosting.fittingSize
      let material = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
      material.material = .hudWindow
      material.blendingMode = .behindWindow
      material.state = .active
      material.updateMask(size: size, radius: Theme.capsuleRadius)
      hosting.frame = material.bounds
      hosting.autoresizingMask = [.width, .height]
      material.addSubview(hosting)
      capsulePanel.contentView = material
      capsulePanel.setContentSize(size)
      positionCapsule()
      capsulePanel.alphaValue = 0
      if !capsulePanel.isVisible {
        panel.addChildWindow(capsulePanel, ordered: .above)
        capsulePanel.orderFront(nil)
      }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = Theme.summonDuration
        capsulePanel.animator().alphaValue = 1
      }
    } else {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = Theme.hideDuration
        capsulePanel.animator().alphaValue = 0
      } completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          guard let self, self.capsuleMotion == generation else { return }
          self.panel.removeChildWindow(self.capsulePanel)
          self.capsulePanel.orderOut(nil)
        }
      }
    }
  }

  private func positionCapsule() {
    capsulePanel.setFrameOrigin(
      NSPoint(
        x: panel.frame.midX - capsulePanel.frame.width / 2,
        y: panel.frame.maxY + Theme.capsuleOffset))
  }

  private func hide() {
    model.hide()
    refreshCapsule()
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

  private func resize() {
    guard model.isVisible, panel.frame.height != model.panelHeight,
      let screen = panel.screen ?? NSScreen.main
    else { return }
    let size = CGSize(width: Theme.panelSize.width, height: model.panelHeight)
    let visible = practiceVisibleFrame(on: screen)
    let placement = PanelLayout.clamp(
      .init(x: panel.frame.minX, y: panel.frame.minY, width: size.width, height: size.height),
      to: .init(visible))
    let frame = NSRect(
      x: placement.x, y: placement.y, width: placement.width, height: placement.height)
    panel.setFrame(frame, display: true)
    (panel.contentView as? NSVisualEffectView)?.updateMask(size: size)
    if capsulePanel.isVisible { positionCapsule() }
  }

  private func show() {
    motion += 1
    model.summon()
    let mouse = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
      let visible = practiceVisibleFrame(on: screen)
      let placement = PanelLayout.position(
        width: Theme.panelSize.width, height: model.panelHeight,
        in: .init(visible),
        offset: model.state.panelOffset, bottom: Theme.bottomOffset)
      panel.setFrame(
        NSRect(
          x: placement.x, y: placement.y,
          width: placement.width, height: placement.height), display: true)
      (panel.contentView as? NSVisualEffectView)?.updateMask(size: panel.frame.size)
    }
    resize()
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
        self?.resize()
        self?.refreshCapsule()
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

  private func drag(by delta: NSPoint) {
    guard
      let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
        ?? panel.screen
    else { return }
    let visible = practiceVisibleFrame(on: screen)
    let frame = PanelLayout.clamp(
      .init(
        x: dragOrigin.x + delta.x, y: dragOrigin.y + delta.y,
        width: panel.frame.width, height: panel.frame.height),
      to: .init(visible))
    panel.setFrameOrigin(NSPoint(x: frame.x, y: frame.y))
  }

  private func saveOffset() {
    guard let screen = panel.screen else { return }
    let visible = screen.visibleFrame
    model.setPanelOffset(
      PanelLayout.offset(
        of: .init(panel.frame),
        in: .init(visible),
        bottom: Theme.bottomOffset))
  }

  private func practiceVisibleFrame(on screen: NSScreen) -> NSRect {
    var visible = screen.visibleFrame
    // Reserve the child's space even while hidden, so holding Command never moves practice.
    visible.size.height -= Theme.capsuleOffset + Theme.capsuleHeight
    return visible
  }

  private func resetPosition() {
    model.setPanelOffset(.init())
    guard let screen = panel.screen else { return }
    let visible = practiceVisibleFrame(on: screen)
    let frame = PanelLayout.position(
      width: panel.frame.width, height: panel.frame.height,
      in: .init(visible),
      offset: .init(), bottom: Theme.bottomOffset)
    panel.setFrameOrigin(NSPoint(x: frame.x, y: frame.y))
  }
}

extension NSVisualEffectView {
  fileprivate func updateMask(size: CGSize, radius: CGFloat = Theme.radius) {
    maskImage = NSImage(size: size, flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
      return true
    }
  }
}

extension PanelLayout.Rect {
  fileprivate init(_ rect: NSRect) {
    self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
  }
}
