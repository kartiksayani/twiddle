import Foundation

public enum PanelLayout {
  public struct Rect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
      self.x = x
      self.y = y
      self.width = width
      self.height = height
    }
  }

  public static func height(view: PracticeModel.ViewState, hints: Bool) -> Double {
    view == .progress ? 185 : hints ? 252 : 136
  }

  public static func clamp(_ frame: Rect, to visible: Rect) -> Rect {
    Rect(
      x: max(visible.x, min(frame.x, visible.x + visible.width - frame.width)),
      y: max(visible.y, min(frame.y, visible.y + visible.height - frame.height)),
      width: frame.width, height: frame.height)
  }

  public static func position(
    width: Double, height: Double, in visible: Rect, offset: Store.PanelOffset,
    bottom: Double
  ) -> Rect {
    clamp(
      Rect(
        x: visible.x + (visible.width - width) / 2 + (offset.x.isFinite ? offset.x : 0),
        y: visible.y + bottom + (offset.y.isFinite ? offset.y : 0),
        width: width, height: height), to: visible)
  }

  public static func offset(of frame: Rect, in visible: Rect, bottom: Double) -> Store.PanelOffset {
    Store.PanelOffset(
      x: frame.x - (visible.x + (visible.width - frame.width) / 2),
      y: frame.y - (visible.y + bottom))
  }
}
