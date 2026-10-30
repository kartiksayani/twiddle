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
}
