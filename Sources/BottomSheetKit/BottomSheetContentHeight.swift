import SwiftUI

extension View {
  /// Reports the natural content height in points for a sheet using `.content` scrolling.
  ///
  /// Measure the contents inside your scroll view, including their own padding, rather than
  /// the scroll viewport. The sheet adds its configured padding, grabber, and safe area once.
  /// Attach once to the sheet content. Changes resize the panel without replacing its content.
  /// Nil, nonpositive, and nonfinite values restore the available height; `.automatic` ignores it.
  public func bottomSheetContentHeight(_ height: CGFloat?) -> some View {
    preference(key: SheetContentHeightKey.self, value: height)
  }
}

struct SheetContentHeightKey: PreferenceKey {
  static let defaultValue: CGFloat? = nil

  static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
    if let next = nextValue() { value = next }
  }
}
