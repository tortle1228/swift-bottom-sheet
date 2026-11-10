import SwiftUI

/// A stable identifier for dismissing a sheet outside its view hierarchy.
public struct BottomSheetID: Hashable, Sendable {
  private let value: String

  /// Creates an identifier. Use a distinct value for each simultaneously presented sheet.
  public init(_ value: String) { self.value = value }
}

@MainActor
protocol SheetDismissTarget: AnyObject {
  func requestDismissal()
}

/// Dismisses registered sheets without owning their presentation state or content.
@MainActor
public final class BottomSheetPresenter {
  /// The process-wide dismissal registry. Identifiers must be unique across windows.
  public static let shared = BottomSheetPresenter()

  private struct Entry {
    weak var target: (any SheetDismissTarget)?
  }
  private var entries: [BottomSheetID: Entry] = [:]

  private init() {}

  /// Requests dismissal of the sheet registered with `id`.
  ///
  /// Does nothing if the identifier is not registered or the sheet is already dismissing.
  /// The presentation binding and callback follow the same lifecycle as an internal dismissal.
  public func dismiss(id: BottomSheetID) { entries[id]?.target?.requestDismissal() }

  func register(_ target: any SheetDismissTarget, id: BottomSheetID) -> Bool {
    if let existing = entries[id]?.target, existing !== target { return false }
    entries[id] = Entry(target: target)
    return true
  }

  func unregister(_ target: any SheetDismissTarget, id: BottomSheetID) {
    if entries[id]?.target === target { entries[id] = nil }
  }
}

/// An action that dismisses the sheet containing the current view.
@MainActor
public struct BottomSheetDismissAction {
  let dismiss: @MainActor () -> Void

  /// Requests dismissal. Outside a bottom sheet this action does nothing.
  public func callAsFunction() { dismiss() }
}

private struct SheetDismissKey: EnvironmentKey {
  static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
  /// The dismissal action for the containing bottom sheet.
  public var bottomSheetDismiss: BottomSheetDismissAction {
    get { BottomSheetDismissAction(dismiss: self[SheetDismissKey.self]) }
    set { self[SheetDismissKey.self] = newValue.dismiss }
  }
}
