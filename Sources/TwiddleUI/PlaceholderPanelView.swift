import SwiftUI

public struct PlaceholderPanelView: View {
  public static let size = CGSize(width: 720, height: 136)

  public init() {}

  public var body: some View {
    Rectangle()
      .fill(.background)
      .frame(width: Self.size.width, height: Self.size.height)
  }
}
