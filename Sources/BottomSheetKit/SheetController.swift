import SwiftUI
import UIKit

@MainActor
private final class ContentScrollView: UIScrollView {
  var didLayout: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    didLayout?()
  }
}

@MainActor
final class SheetController: UIViewController {
  var close: (() -> Void)?
  var didDisappear: (() -> Void)?
  var configuration: BottomSheetConfiguration
  var contentHeight: CGFloat = 320
  private(set) var reportedContentHeight: CGFloat?
  var fillsHeight: Bool {
    configuration.contentScrolling == .content && reportedContentHeight == nil
  }
  var layoutContentHeight: CGFloat {
    guard configuration.contentScrolling == .content, let reportedContentHeight else {
      return contentHeight
    }
    return reportedContentHeight + configuration.contentInsets.top
      + configuration.contentInsets.bottom
  }
  private let host = UIHostingController(rootView: AnyView(EmptyView()))
  private let scroll = ContentScrollView()
  private var fillsContentHeight: NSLayoutConstraint?
  private let handle = UIView()
  private let capsule = UIView()
  private var handleHeight: NSLayoutConstraint?
  private var capsuleConstraints: [NSLayoutConstraint] = []
  private lazy var transition = SheetTransition()

  init(content: AnyView, configuration: BottomSheetConfiguration) {
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .custom
    transitioningDelegate = transition
    update(content: content, configuration: configuration)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  var chromeHeight: CGFloat {
    guard configuration.showsGrabber else { return 0 }
    return max(0, configuration.grabberInsets.top) + max(0, configuration.grabberSize.height)
      + max(0, configuration.grabberInsets.bottom)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.accessibilityViewIsModal = true
    view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    view.clipsToBounds = true
    view.layer.cornerCurve = .continuous
    handle.translatesAutoresizingMaskIntoConstraints = false
    capsule.translatesAutoresizingMaskIntoConstraints = false
    capsule.isAccessibilityElement = false
    handle.addSubview(capsule)
    view.addSubview(handle)
    addChild(host)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.backgroundColor = .clear
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.alwaysBounceVertical = false
    scroll.delaysContentTouches = false
    view.addSubview(scroll)
    scroll.addSubview(host.view)
    host.didMove(toParent: self)
    scroll.didLayout = { [weak self] in
      guard let self else { return }
      self.measureContent(width: self.scroll.bounds.width)
    }
    fillsContentHeight = host.view.heightAnchor.constraint(
      equalTo: scroll.frameLayoutGuide.heightAnchor)
    let height = handle.heightAnchor.constraint(equalToConstant: chromeHeight)
    handleHeight = height
    NSLayoutConstraint.activate([
      handle.topAnchor.constraint(equalTo: view.topAnchor),
      handle.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      handle.trailingAnchor.constraint(equalTo: view.trailingAnchor), height,
      scroll.topAnchor.constraint(equalTo: handle.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
      host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
      host.view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
    ])
    handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))
    applyAppearance()
  }

  func update(content: AnyView, configuration: BottomSheetConfiguration) {
    self.configuration = configuration
    if configuration.contentScrolling == .automatic { reportedContentHeight = nil }
    let observed = content.onPreferenceChange(SheetContentHeightKey.self) { [weak self] height in
      Task { @MainActor [weak self] in self?.reportContentHeight(height) }
    }
    if configuration.contentScrolling == .automatic {
      host.rootView = AnyView(
        observed.frame(maxWidth: .infinity)
          .padding(configuration.contentInsets).fixedSize(horizontal: false, vertical: true))
    } else {
      host.rootView = AnyView(observed.padding(configuration.contentInsets))
    }
    host.sizingOptions = configuration.contentScrolling == .automatic ? .intrinsicContentSize : []
    if isViewLoaded {
      applyAppearance()
      measureContent(width: view.bounds.width)
    }
    presentationController?.containerView?.setNeedsLayout()
    (presentationController as? SheetPresentation)?.layoutPanel()
  }

  func reportContentHeight(_ height: CGFloat?) {
    guard configuration.contentScrolling == .content else { return }
    let valid = height.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    guard valid != reportedContentHeight else { return }
    reportedContentHeight = valid
    presentationController?.containerView?.setNeedsLayout()
    (presentationController as? SheetPresentation)?.layoutPanel()
  }

  func measureContent(width: CGFloat) {
    guard configuration.contentScrolling == .automatic, width > 0 else { return }
    let height = host.sizeThatFits(in: CGSize(width: width, height: 1_000_000)).height
    guard height.isFinite, abs(contentHeight - height) > 0.5 else { return }
    contentHeight = max(0, height)
    preferredContentSize = CGSize(width: width, height: contentHeight)
    (presentationController as? SheetPresentation)?.layoutPanel()
  }

  private func applyAppearance() {
    let automatic = configuration.contentScrolling == .automatic
    scroll.isScrollEnabled = automatic
    fillsContentHeight?.isActive = !automatic
    view.backgroundColor = UIColor(configuration.backgroundColor)
    view.layer.cornerRadius = max(0, configuration.cornerRadius)
    handleHeight?.constant = chromeHeight
    handle.isHidden = !configuration.showsGrabber
    capsule.backgroundColor = UIColor(configuration.grabberColor)
    capsule.layer.cornerRadius = max(0, configuration.grabberSize.height) / 2
    NSLayoutConstraint.deactivate(capsuleConstraints)
    capsuleConstraints = [
      capsule.centerXAnchor.constraint(
        equalTo: handle.centerXAnchor,
        constant: (configuration.grabberInsets.leading - configuration.grabberInsets.trailing) / 2),
      capsule.topAnchor.constraint(
        equalTo: handle.topAnchor, constant: max(0, configuration.grabberInsets.top)),
      capsule.widthAnchor.constraint(equalToConstant: max(0, configuration.grabberSize.width)),
      capsule.heightAnchor.constraint(equalToConstant: max(0, configuration.grabberSize.height)),
    ]
    NSLayoutConstraint.activate(capsuleConstraints)
  }

  @objc private func drag(_ recognizer: UIPanGestureRecognizer) {
    guard configuration.dismissesOnDrag else { return }
    let distance = max(0, recognizer.translation(in: view).y)
    switch recognizer.state {
    case .changed:
      view.transform = CGAffineTransform(translationX: 0, y: distance)
    case .ended, .cancelled:
      if recognizer.state == .ended && (distance > 80 || recognizer.velocity(in: view).y > 800) {
        close?()
      } else {
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2) {
          self.view.transform = .identity
        }
      }
    default: break
    }
  }

  override func accessibilityPerformEscape() -> Bool {
    guard configuration.dismissesOnDrag || configuration.dismissesOnBackdropTap else {
      return false
    }
    close?()
    return true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    UIAccessibility.post(notification: .screenChanged, argument: view)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if presentingViewController == nil { didDisappear?() }
  }
}
