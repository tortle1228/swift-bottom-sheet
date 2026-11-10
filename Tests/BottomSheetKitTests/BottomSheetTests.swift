import SwiftUI
import Testing
import UIKit

@testable import BottomSheetKit

struct SheetLayoutTests {
  private let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
  private let safe = UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)

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
