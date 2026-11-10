import XCTest

@MainActor
final class SheetUITests: XCTestCase {
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
}
