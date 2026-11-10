import XCTest

@MainActor
final class SheetUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }
  func testAdaptiveLayout() {
    let app = XCUIApplication()
    for largeText in [false, true] {
      app.launchArguments = largeText ? ["-showInput", "-accessibilityText"] : ["-showInput"]
      app.launch()
      let button = app.buttons["Environment close"]
      XCTAssertTrue(button.waitForExistence(timeout: 5))
      XCTAssertTrue(button.isHittable)
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = largeText ? "Accessibility text" : "Default text"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      button.tap()
      XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
      app.terminate()
    }
  }

  func testDismissalPathsAndReopen() {
    let app = XCUIApplication()
    app.launch()
    for (index, title) in ["Environment close", "Binding close", "Global close"].enumerated() {
      app.buttons["Show input"].tap()
      XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
      app.buttons[title].tap()
      XCTAssertTrue(app.staticTexts["Dismissals: \(index + 1)"].waitForExistence(timeout: 5))
    }
  }

  func testKeyboardAndLongContent() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["Show input"].tap()
    let field = app.textFields["email"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    field.typeText("hello@example.com")
    app.buttons["Environment close"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
    app.buttons["Show long content"].tap()
    let end = app.buttons["End close"]
    for _ in 0..<25 {
      if end.isHittable { break }
      app.scrollViews.firstMatch.swipeUp()
    }
    XCTAssertTrue(end.isHittable)
    end.tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 2"].waitForExistence(timeout: 5))
  }

  func testBackdropAndDrag() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["Show input"].tap()
    XCTAssertTrue(app.buttons["Environment close"].waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
    app.buttons["Show input"].tap()
    let title = app.staticTexts["Sign in"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    let grabber = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
      .withOffset(CGVector(dx: 0, dy: -25))
    grabber.press(forDuration: 0.1, thenDragTo: grabber.withOffset(CGVector(dx: 0, dy: 180)))
    XCTAssertTrue(app.staticTexts["Dismissals: 2"].waitForExistence(timeout: 5))
  }

  func testItemReplacementAndOwnScrolling() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["Show item"].tap()
    XCTAssertTrue(app.staticTexts["Item 1"].waitForExistence(timeout: 5))
    app.buttons["Replace item"].tap()
    XCTAssertTrue(app.staticTexts["Item 2"].waitForExistence(timeout: 5))
    app.buttons["Clear item"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 2"].waitForExistence(timeout: 5))
    app.buttons["Show list"].tap()
    XCTAssertTrue(app.staticTexts["Row 0"].waitForExistence(timeout: 5))
    app.swipeUp()
    XCTAssertFalse(app.staticTexts["Row 0"].isHittable)
  }

  func testContentSizedFormHeightAndEnvironment() {
    let app = XCUIApplication()
    app.launchArguments = ["-showForm"]
    app.launch()
    let title = app.staticTexts["Content-sized form"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Injected environment"].exists)
    XCTAssertTrue(app.staticTexts["Explicit custom environment"].exists)
    let scroll = app.scrollViews.firstMatch
    XCTAssertLessThanOrEqual(scroll.frame.width, 600.5)
    let original = scroll.frame.height
    app.buttons["Load details"].tap()
    XCTAssertTrue(app.buttons["Hide details"].waitForExistence(timeout: 5))
    let grew = NSPredicate { _, _ in scroll.frame.height > original + 50 }
    expectation(for: grew, evaluatedWith: nil)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(app.webViews.firstMatch.exists)
    app.buttons["Hide details"].tap()
    let shrank = NSPredicate { _, _ in abs(scroll.frame.height - original) < 2 }
    expectation(for: shrank, evaluatedWith: nil)
    waitForExpectations(timeout: 5)
    app.buttons["Close form"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
  }

  func testFormLockAndSystemModalLifecycle() {
    let app = XCUIApplication()
    app.launchArguments = ["-showForm"]
    app.launch()
    XCTAssertTrue(app.buttons["Submit"].waitForExistence(timeout: 5))
    app.buttons["Submit"].tap()
    XCTAssertTrue(app.buttons["Finish submission"].waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    XCTAssertTrue(app.buttons["Finish submission"].exists)
    app.buttons["Finish submission"].tap()
    XCTAssertTrue(app.staticTexts["formError"].waitForExistence(timeout: 5))
    app.buttons["Open system modal"].tap()
    XCTAssertTrue(app.buttons["Close system modal"].waitForExistence(timeout: 5))
    app.buttons["Close system modal"].tap()
    XCTAssertTrue(app.buttons["Close form"].waitForExistence(timeout: 5))
    app.buttons["Continue after dismissal"].tap()
    XCTAssertTrue(app.buttons["Follow-up complete"].waitForExistence(timeout: 5))
    app.buttons["Follow-up complete"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
  }

  func testSameItemUpdatePreservesDraft() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["Show item"].tap()
    let draft = app.textFields["itemDraft"]
    XCTAssertTrue(draft.waitForExistence(timeout: 5))
    draft.tap()
    draft.typeText("Saved draft")
    app.buttons["Update item"].tap()
    XCTAssertTrue(app.staticTexts["Revision 1"].waitForExistence(timeout: 5))
    XCTAssertEqual(draft.value as? String, "Saved draft")
    app.buttons["Replace item"].tap()
    XCTAssertTrue(app.staticTexts["Item 2"].waitForExistence(timeout: 5))
    XCTAssertNotEqual(app.textFields["itemDraft"].value as? String, "Saved draft")
    app.buttons["Clear item"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 2"].waitForExistence(timeout: 5))
  }

  func testFormKeyboardAndFocus() {
    let app = XCUIApplication()
    app.launchArguments = ["-showForm", "-focusForm"]
    app.launch()
    let email = app.textFields["formEmail"]
    XCTAssertTrue(email.waitForExistence(timeout: 5))
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    email.typeText("test@example.com\n")
    app.secureTextFields["formPassword"].typeText("sample-password\n")
    XCTAssertTrue(app.buttons["Finish submission"].waitForExistence(timeout: 5))
    app.buttons["Finish submission"].tap()
    XCTAssertTrue(app.staticTexts["formError"].waitForExistence(timeout: 5))
    XCTAssertEqual(email.value as? String, "test@example.com")
    app.buttons["Close form"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
  }

  func testFormAdaptiveLayout() {
    let app = XCUIApplication()
    for largeText in [false, true] {
      app.launchArguments = largeText ? ["-showForm", "-accessibilityText"] : ["-showForm"]
      app.launch()
      XCTAssertTrue(app.staticTexts["Content-sized form"].waitForExistence(timeout: 5))
      XCTAssertLessThanOrEqual(app.scrollViews.firstMatch.frame.width, 600.5)
      let close = app.buttons["Close form"]
      for _ in 0..<6 {
        if close.isHittable { break }
        app.scrollViews.firstMatch.swipeUp()
      }
      XCTAssertTrue(close.isHittable)
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = largeText ? "Form accessibility text" : "Form default text"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      close.tap()
      XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
      app.terminate()
    }
  }

  func testLockedFormAllowsExplicitDismissal() {
    let app = XCUIApplication()
    app.launchArguments = ["-showForm"]
    app.launch()
    XCTAssertTrue(app.buttons["Submit"].waitForExistence(timeout: 5))
    app.buttons["Submit"].tap()
    let title = app.staticTexts["Content-sized form"]
    let grabber = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
      .withOffset(CGVector(dx: 0, dy: -25))
    grabber.press(forDuration: 0.1, thenDragTo: grabber.withOffset(CGVector(dx: 0, dy: 180)))
    XCTAssertTrue(app.buttons["Finish submission"].exists)
    app.buttons["Close form"].tap()
    XCTAssertTrue(app.staticTexts["Dismissals: 1"].waitForExistence(timeout: 5))
  }
}
