import SwiftUI

extension View {
  /// Presents a content-sized bottom sheet while `isPresented` is true.
  ///
  /// Inherits text size, color scheme, locale, and layout direction from the presenter.
  /// Inject other environment values and objects into `content` explicitly.
  /// Only one sheet is presented by each modifier. Attach the modifier to a stable view.
  /// A dismissal clears the binding when requested and calls `onDismiss` after the transition.
  /// Duplicate active identifiers are rejected; the rejected presentation resets its binding.
  ///
  /// - Parameters:
  ///   - isPresented: The source of truth for presentation.
  ///   - id: An optional identifier for global dismissal, unique across all windows.
  ///   - configuration: The panel appearance and user dismissal behavior.
  ///   - onDismiss: Called once after a presented sheet finishes dismissing.
  ///   - content: The sheet content. Use the environment's `bottomSheetDismiss` to close it.
  @MainActor
  public func bottomSheet<Content: View>(
    isPresented: Binding<Bool>,
    id: BottomSheetID? = nil,
    configuration: BottomSheetConfiguration = .init(),
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    background(
      SheetBridge(
        isPresented: isPresented.wrappedValue,
        identity: nil,
        id: id,
        configuration: configuration,
        content: { AnyView(content()) },
        clear: { isPresented.wrappedValue = false },
        onDismiss: onDismiss
      ).frame(width: 0, height: 0)
    )
  }

  /// Presents a sheet for a non-nil identifiable item.
  ///
  /// Inherits text size, color scheme, locale, and layout direction from the presenter.
  /// Inject other environment values and objects into `content` explicitly.
  /// Changing the item identity dismisses the old sheet before presenting the new one.
  /// Updating an item with the same identity refreshes its content in place.
  /// Dismissal clears the item only if it still has the identity being dismissed.
  ///
  /// - Parameters:
  ///   - item: The optional source of truth for presentation and content.
  ///   - id: An optional, globally unique dismissal identifier.
  ///   - configuration: The panel appearance and user dismissal behavior.
  ///   - onDismiss: Called once per completed dismissal.
  ///   - content: Creates content for the currently presented item.
  @MainActor
  public func bottomSheet<Item: Identifiable, Content: View>(
    item: Binding<Item?>,
    id: BottomSheetID? = nil,
    configuration: BottomSheetConfiguration = .init(),
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    let value = item.wrappedValue
    return background(
      SheetBridge(
        isPresented: value != nil,
        identity: value.map { AnyHashable($0.id) },
        id: id,
        configuration: configuration,
        content: { AnyView(value.map { content($0) }) },
        clear: {
          if item.wrappedValue?.id == value?.id { item.wrappedValue = nil }
        },
        onDismiss: onDismiss
      ).frame(width: 0, height: 0)
    )
  }
}

@MainActor
struct SheetBridge: UIViewControllerRepresentable {
  var inheritedEnvironment: EnvironmentValues?
  var isPresented: Bool
  var identity: AnyHashable?
  var id: BottomSheetID?
  var configuration: BottomSheetConfiguration
  var content: () -> AnyView
  var clear: () -> Void
  var onDismiss: (() -> Void)?

  func makeCoordinator() -> SheetCoordinator { SheetCoordinator() }

  func makeUIViewController(context: Context) -> SheetAnchor {
    let anchor = SheetAnchor()
    context.coordinator.anchor = anchor
    anchor.ready = { [weak coordinator = context.coordinator] in coordinator?.reconcile() }
    return anchor
  }

  func updateUIViewController(_ controller: SheetAnchor, context: Context) {
    var bridge = self
    bridge.inheritedEnvironment = context.environment
    context.coordinator.desired = bridge
    // Binding writes and UIKit presentation must happen after SwiftUI's update pass.
    Task { @MainActor [weak coordinator = context.coordinator] in coordinator?.reconcile() }
  }

  static func dismantleUIViewController(_ controller: SheetAnchor, coordinator: SheetCoordinator) {
    coordinator.desired = nil
    coordinator.reconcile()
  }
}

@MainActor
final class SheetAnchor: UIViewController {
  var ready: (() -> Void)?

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    ready?()
  }
}

@MainActor
final class SheetCoordinator: NSObject, SheetDismissTarget {
  weak var anchor: SheetAnchor?
  var desired: SheetBridge?
  private var active: SheetBridge?
  private var sheet: SheetController?
  private var transitioning = false
  private var dismissalRequested = false

  func requestDismissal() {
    guard sheet != nil, !dismissalRequested else { return }
    dismissalRequested = true
    clearActivePresentation()
    reconcile()
  }

  func reconcile() {
    guard !transitioning else { return }
    if let sheet, let active {
      let replacing = desired?.identity != active.identity || desired?.id != active.id
      if dismissalRequested || desired?.isPresented != true || replacing {
        transitioning = true
        sheet.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [self] in
          finishDismissal()
        }
      } else if let desired {
        self.active = desired
        sheet.overrideUserInterfaceStyle =
          desired.inheritedEnvironment?.colorScheme == .dark ? .dark : .light
        sheet.update(content: wrappedContent(desired), configuration: desired.configuration)
      }
      return
    }
    guard let desired, desired.isPresented, let anchor, anchor.viewIfLoaded?.window != nil,
      let parent = anchor.parent
    else { return }
    if let presented = parent.presentedViewController {
      // Nothing else brings this sheet back once another presentation has left, so wait for it here.
      if presented.isBeingDismissed, let leaving = presented.transitionCoordinator {
        leaving.animate(alongsideTransition: nil) { [weak self] _ in self?.reconcile() }
      }
      return
    }
    if let id = desired.id, !BottomSheetPresenter.shared.register(self, id: id) {
      NSLog("BottomSheetKit: duplicate active sheet identifier")
      desired.clear()
      return
    }
    active = desired
    dismissalRequested = false
    let controller = SheetController(
      content: wrappedContent(desired), configuration: desired.configuration)
    controller.overrideUserInterfaceStyle =
      desired.inheritedEnvironment?.colorScheme == .dark ? .dark : .light
    controller.close = { [weak self] in self?.requestDismissal() }
    controller.didDisappear = { [weak self] in
      guard let self, !self.transitioning else { return }
      self.clearActivePresentation()
      self.finishDismissal()
    }
    controller.loadViewIfNeeded()
    controller.measureContent(
      width: SheetLayout.width(
        bounds: parent.view.bounds, safeArea: parent.view.safeAreaInsets,
        maximumWidth: desired.configuration.maximumWidth))
    sheet = controller
    transitioning = true
    parent.present(controller, animated: !UIAccessibility.isReduceMotionEnabled) { [self] in
      transitioning = false
      reconcile()
    }
  }

  private func clearActivePresentation() {
    // A late dismissal must not discard a replacement that already has a new identity.
    if desired?.identity == active?.identity && desired?.id == active?.id {
      desired?.isPresented = false
    }
    active?.clear()
  }

  private func wrappedContent(_ bridge: SheetBridge) -> AnyView {
    AnyView(
      bridge.content()
        .environment(\.dynamicTypeSize, bridge.inheritedEnvironment?.dynamicTypeSize ?? .large)
        .environment(\.colorScheme, bridge.inheritedEnvironment?.colorScheme ?? .light)
        .environment(\.locale, bridge.inheritedEnvironment?.locale ?? .current)
        .environment(
          \.layoutDirection, bridge.inheritedEnvironment?.layoutDirection ?? .leftToRight
        )
        .environment(
          \.bottomSheetDismiss,
          BottomSheetDismissAction { [weak self] in
            self?.requestDismissal()
          }))
  }

  private func finishDismissal() {
    guard let active else { return }
    if let id = active.id { BottomSheetPresenter.shared.unregister(self, id: id) }
    sheet = nil
    self.active = nil
    transitioning = false
    dismissalRequested = false
    active.onDismiss?()
    Task { @MainActor [weak self] in self?.reconcile() }
  }
}
