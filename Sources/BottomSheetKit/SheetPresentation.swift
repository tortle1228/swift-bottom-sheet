import UIKit

struct SheetLayout {
  static func width(bounds: CGRect, safeArea: UIEdgeInsets, maximumWidth: CGFloat?) -> CGFloat {
    let available = max(0, bounds.width - safeArea.left - safeArea.right)
    guard let maximumWidth, maximumWidth.isFinite, maximumWidth > 0 else { return available }
    return min(available, maximumWidth)
  }

  static func frame(
    bounds: CGRect, safeArea: UIEdgeInsets, keyboardTop: CGFloat?, contentHeight: CGFloat,
    chromeHeight: CGFloat, fillsHeight: Bool, maximumWidth: CGFloat? = nil
  ) -> CGRect {
    let bottom = min(bounds.maxY, max(bounds.minY, keyboardTop ?? bounds.maxY))
    let top = min(bottom, bounds.minY + safeArea.top + 12)
    let available = max(0, bottom - top)
    // The keyboard replaces the bottom safe area rather than adding another inset.
    let inset = bottom < bounds.maxY ? 0 : safeArea.bottom
    let desired = max(0, contentHeight) + max(0, chromeHeight) + inset
    let height = fillsHeight ? available : min(available, desired)
    let width = width(bounds: bounds, safeArea: safeArea, maximumWidth: maximumWidth)
    let left = bounds.minX + safeArea.left
    let availableWidth = max(0, bounds.width - safeArea.left - safeArea.right)
    return CGRect(
      x: left + (availableWidth - width) / 2, y: bottom - height, width: width, height: height)
  }
}

@MainActor
final class SheetPresentation: UIPresentationController {
  private let backdrop = UIControl()
  private let keyboardBackground = UIView()
  private var keyboardTop: CGFloat?
  private weak var previousFocus: NSObject?
  private var sheet: SheetController? { presentedViewController as? SheetController }

  override var frameOfPresentedViewInContainerView: CGRect {
    guard let containerView, let sheet else { return .zero }
    return SheetLayout.frame(
      bounds: containerView.bounds, safeArea: containerView.safeAreaInsets,
      keyboardTop: keyboardTop,
      contentHeight: sheet.layoutContentHeight, chromeHeight: sheet.chromeHeight,
      fillsHeight: sheet.fillsHeight, maximumWidth: sheet.configuration.maximumWidth
    )
  }

  override func presentationTransitionWillBegin() {
    guard let containerView else { return }
    previousFocus = UIAccessibility.focusedElement(using: .notificationVoiceOver) as? NSObject
    backdrop.addTarget(self, action: #selector(tapBackdrop), for: .touchUpInside)
    backdrop.isAccessibilityElement = false
    keyboardBackground.isUserInteractionEnabled = false
    backdrop.addSubview(keyboardBackground)
    containerView.insertSubview(backdrop, at: 0)
    backdrop.alpha = 0
    updateBackdrop()
    presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
      self.backdrop.alpha = 1
    })
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboard(_:)),
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(keyboard(_:)),
      name: UIResponder.keyboardWillHideNotification, object: nil)
  }

  override func presentationTransitionDidEnd(_ completed: Bool) {
    if !completed { cleanUp() }
  }

  override func dismissalTransitionWillBegin() {
    presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
      self.backdrop.alpha = 0
    })
  }

  override func dismissalTransitionDidEnd(_ completed: Bool) {
    if completed {
      cleanUp()
      UIAccessibility.post(notification: .screenChanged, argument: previousFocus)
    } else {
      backdrop.alpha = 1
    }
  }

  private func cleanUp() {
    NotificationCenter.default.removeObserver(self)
    backdrop.removeFromSuperview()
  }

  override func containerViewWillLayoutSubviews() {
    super.containerViewWillLayoutSubviews()
    sheet?.measureContent(width: frameOfPresentedViewInContainerView.width)
    layoutPanel()
  }

  func layoutPanel() {
    guard let containerView else { return }
    backdrop.frame = containerView.bounds
    // Reset the drag transform before setting a frame; UIKit frames are undefined under transforms.
    let transform = presentedView?.transform ?? .identity
    presentedView?.transform = .identity
    presentedView?.frame = frameOfPresentedViewInContainerView
    presentedView?.transform = transform
    // Continue the panel color behind the keyboard's rounded top corners.
    let panel = frameOfPresentedViewInContainerView
    keyboardBackground.frame = CGRect(
      x: panel.minX, y: panel.maxY, width: panel.width,
      height: max(0, backdrop.bounds.maxY - panel.maxY))
    updateBackdrop()
  }

  private func updateBackdrop() {
    guard let config = sheet?.configuration else { return }
    keyboardBackground.backgroundColor = UIColor(config.backgroundColor)
    backdrop.backgroundColor = UIColor(config.dimmingColor).withAlphaComponent(
      min(1, max(0, config.dimmingOpacity)))
  }

  @objc private func tapBackdrop() {
    if sheet?.configuration.dismissesOnBackdropTap == true { sheet?.close?() }
  }

  @objc private func keyboard(_ notification: Notification) {
    guard let containerView, let window = containerView.window,
      let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
    else { return }
    let local = containerView.convert(
      window.convert(frame, from: window.screen.coordinateSpace), from: window)
    let docked =
      local.intersects(containerView.bounds) && local.maxY >= containerView.bounds.maxY - 1
    keyboardTop =
      notification.name == UIResponder.keyboardWillHideNotification || !docked ? nil : local.minY
    let duration =
      notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
    let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
    containerView.setNeedsLayout()
    UIView.animate(
      withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : duration, delay: 0,
      options: UIView.AnimationOptions(rawValue: curve << 16)
    ) { containerView.layoutIfNeeded() }
  }
}

@MainActor
final class SheetTransition: NSObject, UIViewControllerTransitioningDelegate,
  UIViewControllerAnimatedTransitioning
{
  func presentationController(
    forPresented presented: UIViewController, presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    SheetPresentation(presentedViewController: presented, presenting: presenting)
  }

  func animationController(
    forPresented presented: UIViewController, presenting: UIViewController,
    source: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? { self }

  func animationController(forDismissed dismissed: UIViewController) -> (
    any UIViewControllerAnimatedTransitioning
  )? { self }

  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?)
    -> TimeInterval
  {
    UIAccessibility.isReduceMotionEnabled ? 0 : 0.25
  }

  static func offscreenTransform(for view: UIView, containerBounds: CGRect) -> CGAffineTransform {
    // Center and bounds remain valid when a dismissal starts from a drag transform.
    let top = view.center.y - view.bounds.height / 2
    return CGAffineTransform(translationX: 0, y: containerBounds.maxY - top)
  }

  func animateTransition(using context: any UIViewControllerContextTransitioning) {
    guard let to = context.viewController(forKey: .to),
      let from = context.viewController(forKey: .from)
    else {
      context.completeTransition(false)
      return
    }
    let presenting = to.isBeingPresented
    let controller = presenting ? to : from
    guard let view = controller.view else {
      context.completeTransition(false)
      return
    }
    if presenting {
      context.containerView.addSubview(view)
      view.frame = context.finalFrame(for: controller)
    }
    let offscreen = Self.offscreenTransform(
      for: view, containerBounds: context.containerView.bounds)
    if presenting { view.transform = offscreen }
    UIView.animate(
      withDuration: transitionDuration(using: context), delay: 0, options: [.curveEaseOut]
    ) {
      view.transform = presenting ? .identity : offscreen
    } completion: { _ in
      let completed = !context.transitionWasCancelled
      if !completed || !presenting { view.transform = .identity }
      context.completeTransition(completed)
    }
  }
}
