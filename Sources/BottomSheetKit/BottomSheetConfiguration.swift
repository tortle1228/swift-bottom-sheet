import SwiftUI

/// The appearance and user-initiated dismissal behavior of a bottom sheet.
public struct BottomSheetConfiguration {
  /// Who provides scrolling when content exceeds the available height.
  public enum ContentScrolling {
    /// The sheet wraps ordinary content in a scroll view.
    case automatic
    /// The content supplies scrolling and fills the available height unless it reports a
    /// preferred height with `bottomSheetContentHeight(_:)`.
    case content
  }

  /// The panel color, continued behind a docked keyboard. Defaults to the system background color.
  public var backgroundColor: Color = Color(UIColor.systemBackground)
  /// The maximum panel width in points, centered within the horizontal safe area.
  /// Defaults to nil (available width). Nonpositive and nonfinite values are ignored.
  public var maximumWidth: CGFloat?
  /// The top corner radius in points. Defaults to 32.
  public var cornerRadius: CGFloat = 32
  /// Whether the grabber is visible. Defaults to true.
  public var showsGrabber = true
  /// The grabber size in points. Defaults to 40 by 5.
  public var grabberSize = CGSize(width: 40, height: 5)
  /// The grabber color. Defaults to secondary gray.
  public var grabberColor: Color = Color(UIColor.systemGray3)
  /// The padding around the grabber, in points. Defaults to 8 above and 20 below.
  public var grabberInsets = EdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0)
  /// The content padding in points, excluding the bottom safe area.
  /// Defaults to zero above, 20 on each side, and 32 below.
  public var contentInsets = EdgeInsets(top: 0, leading: 20, bottom: 32, trailing: 20)
  /// The backdrop color. Defaults to black.
  public var dimmingColor: Color = .black
  /// The backdrop opacity, clamped to zero through one. Defaults to 0.5.
  public var dimmingOpacity: Double = 0.5
  /// Whether tapping the backdrop dismisses the sheet. Defaults to true.
  public var dismissesOnBackdropTap = true
  /// Whether dragging the grabber downward dismisses the sheet. Defaults to true.
  public var dismissesOnDrag = true
  /// The scrolling owner. Defaults to automatic.
  public var contentScrolling: ContentScrolling = .automatic

  /// Creates the default bottom sheet appearance and dismissal behavior.
  public init() {}
}
