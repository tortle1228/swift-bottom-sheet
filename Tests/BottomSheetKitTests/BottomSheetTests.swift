import SwiftUI
import Testing
import UIKit

@testable import BottomSheetKit

struct SheetLayoutTests {
  private let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
  private let safe = UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)

  @Test(arguments: [CGFloat(600), 2000, 0, -10, .infinity, .nan])
  func maximumWidthUsesAvailableSafeArea(limit: CGFloat) {
    let container = CGRect(x: 10, y: 20, width: 1000, height: 1000)
    let insets = UIEdgeInsets(top: 24, left: 20, bottom: 20, right: 40)
    let frame = SheetLayout.frame(
      bounds: container, safeArea: insets, keyboardTop: nil, contentHeight: 200,
      chromeHeight: 33, fillsHeight: false, maximumWidth: limit)
    let expected: CGFloat = limit == 600 ? 600 : 940
    #expect(frame.width == expected)
    #expect(frame.midX == 500)
    #expect(frame.maxY == container.maxY)
  }

  @Test func widthLimitNeverOverflowsSmallWindow() {
    let frame = SheetLayout.frame(
      bounds: bounds, safeArea: safe, keyboardTop: 500, contentHeight: 1000,
      chromeHeight: 33, fillsHeight: false, maximumWidth: 600)
    #expect(frame.width == 390)
    #expect(frame.minY == 59)
    #expect(frame.maxY == 500)
  }

  @Test func contentHeightIncludesBottomSafeAreaOnce() {
    let frame = SheetLayout.frame(
      bounds: bounds, safeArea: safe, keyboardTop: nil,
      contentHeight: 200, chromeHeight: 33, fillsHeight: false)
    #expect(frame == CGRect(x: 0, y: 577, width: 390, height: 267))
  }

  @Test func keyboardReplacesBottomInset() {
    let frame = SheetLayout.frame(
      bounds: bounds, safeArea: safe, keyboardTop: 500,
      contentHeight: 200, chromeHeight: 33, fillsHeight: false)
    #expect(frame.maxY == 500)
    #expect(frame.height == 233)
  }

  @Test(arguments: [false, true]) func tallContentStaysBelowTopSafeArea(fill: Bool) {
    let frame = SheetLayout.frame(
      bounds: bounds, safeArea: safe, keyboardTop: nil,
      contentHeight: 5000, chromeHeight: 33, fillsHeight: fill)
    #expect(frame.minY == 59)
    #expect(frame.maxY == bounds.maxY)
  }

  @Test func emptyAvailableSpaceNeverProducesNegativeHeight() {
    let frame = SheetLayout.frame(
      bounds: bounds, safeArea: safe, keyboardTop: 10,
      contentHeight: 200, chromeHeight: 33, fillsHeight: false)
    #expect(frame.height == 0)
  }
}

@Suite(.serialized)
@MainActor
struct PresenterTests {
  @Test func contentHeightPreferenceReachesHostingController() async throws {
    var config = BottomSheetConfiguration()
    config.contentScrolling = .content
    let controller = SheetController(
      content: AnyView(ScrollView { Text("Content") }.bottomSheetContentHeight(200)),
      configuration: config)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    controller.view.layoutIfNeeded()
    for _ in 0..<100 {
      if controller.reportedContentHeight == 200 { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(controller.reportedContentHeight == 200)
  }

  @Test func reportedHeightAddsPaddingOnceAndCanReturnToFullHeight() {
    var config = BottomSheetConfiguration()
    config.contentScrolling = .content
    config.contentInsets = EdgeInsets(top: 10, leading: 20, bottom: 30, trailing: 20)
    let controller = SheetController(
      content: AnyView(ScrollView { Text("Content") }), configuration: config)
    controller.loadViewIfNeeded()
    #expect(controller.fillsHeight)
    controller.reportContentHeight(200)
    #expect(!controller.fillsHeight)
    #expect(controller.layoutContentHeight == 240)
    controller.reportContentHeight(400)
    #expect(controller.layoutContentHeight == 440)
    for invalid: CGFloat? in [nil, 0, -1, .infinity, .nan] {
      controller.reportContentHeight(invalid)
      #expect(controller.fillsHeight)
      controller.reportContentHeight(200)
    }
    config.contentScrolling = .automatic
    controller.update(content: AnyView(Text("Short")), configuration: config)
    controller.reportContentHeight(1000)
    #expect(controller.reportedContentHeight == nil)
    #expect(controller.layoutContentHeight < 1000)
  }

  @Test func naturalHeightRemeasuresAtNarrowerWidth() {
    let controller = SheetController(
      content: AnyView(Text(String(repeating: "Wrapping content ", count: 30))),
      configuration: .init())
    controller.loadViewIfNeeded()
    controller.measureContent(width: 600)
    let wideHeight = controller.contentHeight
    controller.measureContent(width: 300)
    #expect(controller.contentHeight > wideHeight)
  }

  @Test func dismissalLockAlsoBlocksAccessibilityEscape() {
    var config = BottomSheetConfiguration()
    config.dismissesOnBackdropTap = false
    config.dismissesOnDrag = false
    let controller = SheetController(content: AnyView(Text("Submitting")), configuration: config)
    var closed = 0
    controller.close = { closed += 1 }
    #expect(!controller.accessibilityPerformEscape())
    #expect(closed == 0)
    config.dismissesOnDrag = true
    controller.update(content: AnyView(Text("Done")), configuration: config)
    #expect(controller.accessibilityPerformEscape())
    #expect(closed == 1)
  }
  @Test(arguments: [CGFloat(59), 577, 267])
  func transitionEndsAtScreenBottom(top: CGFloat) {
    let container = CGRect(x: 0, y: 0, width: 390, height: 844)
    let view = UIView(frame: CGRect(x: 0, y: top, width: 390, height: 233))
    let target = SheetTransition.offscreenTransform(for: view, containerBounds: container)
    #expect(top + target.ty == container.maxY)
    view.transform = CGAffineTransform(translationX: 0, y: 90)
    #expect(SheetTransition.offscreenTransform(for: view, containerBounds: container) == target)
  }

  private final class Target: SheetDismissTarget {
    var calls = 0
    func requestDismissal() { calls += 1 }
  }

  @Test func duplicateIDsCannotStealRegistration() {
    let presenter = BottomSheetPresenter.shared
    let id = BottomSheetID(UUID().uuidString)
    let first = Target()
    let second = Target()
    #expect(presenter.register(first, id: id))
    #expect(!presenter.register(second, id: id))
    presenter.unregister(second, id: id)
    presenter.dismiss(id: id)
    #expect(first.calls == 1)
    #expect(second.calls == 0)
    presenter.unregister(first, id: id)
    presenter.dismiss(id: id)
    #expect(first.calls == 1)
  }

  @Test func registryDoesNotRetainTarget() {
    let id = BottomSheetID(UUID().uuidString)
    var target: Target? = Target()
    weak var weakTarget = target
    if let target { #expect(BottomSheetPresenter.shared.register(target, id: id)) }
    target = nil
    #expect(weakTarget == nil)
    let replacement = Target()
    #expect(BottomSheetPresenter.shared.register(replacement, id: id))
    BottomSheetPresenter.shared.unregister(replacement, id: id)
  }

  @Test func environmentActionRunsInjectedDismissal() {
    var calls = 0
    let action = BottomSheetDismissAction { calls += 1 }
    action()
    #expect(calls == 1)
    EnvironmentValues().bottomSheetDismiss()
    #expect(calls == 1)
  }

  @Test func naturalHeightTracksContentAndDynamicType() {
    let controller = SheetController(
      content: AnyView(Text("Short content")), configuration: .init())
    controller.loadViewIfNeeded()
    controller.measureContent(width: 390)
    let originalHeight = controller.contentHeight
    #expect(originalHeight < 100)
    controller.update(
      content: AnyView(Text("Short content").dynamicTypeSize(.accessibility5)),
      configuration: .init())
    controller.measureContent(width: 390)
    #expect(controller.contentHeight > originalHeight)
  }

  @Test func controllerAppliesAppearanceAndRefreshesChrome() {
    var config = BottomSheetConfiguration()
    let controller = SheetController(content: AnyView(Text("Content")), configuration: config)
    controller.loadViewIfNeeded()
    #expect(controller.chromeHeight == 33)
    #expect(controller.view.layer.cornerRadius == 32)
    config.showsGrabber = false
    config.cornerRadius = 20
    controller.update(content: AnyView(Text("New content")), configuration: config)
    #expect(controller.chromeHeight == 0)
    #expect(controller.view.layer.cornerRadius == 20)
  }
}
