import XCTest

@MainActor
final class GlintwakeUITests: XCTestCase {
    func testFixedLayoutRussianLocalizationAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["help"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["help"].label, "Как играть")
        XCTAssertTrue(app.staticTexts["Первый свет"].exists)
        XCTAssertEqual(app.scrollViews.count, 0)
        let board = app.descendants(matching: .any)["board"].firstMatch
        let original = board.frame
        app.buttons["direction-2"].tap()
        let start = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(board.frame, original)
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let screen = app.windows.firstMatch
            expectation(for: NSPredicate { _, _ in
                orientation == .portrait ? screen.frame.height > screen.frame.width : screen.frame.width > screen.frame.height
            }, evaluatedWith: screen)
            waitForExpectations(timeout: 5)
            for id in ["help", "direction-0", "direction-4", "hint", "undo", "restart"] {
                let element = app.buttons[id]
                XCTAssertTrue(element.isHittable, "Control offscreen: \(id)")
                XCTAssertTrue(screen.frame.contains(element.frame), "Clipped: \(id)")
            }
            XCTAssertTrue(screen.frame.contains(board.frame))
            XCTAssertEqual(app.scrollViews.count, 0)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = orientation == .portrait ? "Russian portrait" : "Russian landscape"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSwipeAndSessionRestoration() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let board = app.descendants(matching: .any)["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        let start = board.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        let end = board.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        app.terminate()
        app.launchArguments.append("--keep-test-session")
        app.launch()
        XCTAssertTrue(app.buttons["undo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        app.buttons["undo"].tap()
        XCTAssertFalse(app.buttons["undo"].isEnabled)
    }

    func testFirstRouteUndoHintVictoryAndNext() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["direction-2"].waitForExistence(timeout: 10))
        app.buttons["direction-2"].tap()
        app.buttons["undo"].tap()
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["guidance"].label.contains("highlighted"))
        for direction in [2, 4, 6] {
            let button = app.buttons["direction-\(direction)"]
            let ready = NSPredicate(format: "enabled == true")
            expectation(for: ready, evaluatedWith: button)
            waitForExpectations(timeout: 3)
            button.tap()
        }
        XCTAssertTrue(app.staticTexts["victory"].waitForExistence(timeout: 5))
        app.buttons["result-action"].tap()
        XCTAssertTrue(app.staticTexts["Across the current"].waitForExistence(timeout: 5))
        app.buttons["levels"].tap()
        XCTAssertTrue(app.buttons["level-2"].waitForExistence(timeout: 3))
        app.buttons["level-2"].tap()
        XCTAssertTrue(app.buttons["brake"].waitForExistence(timeout: 3))
        app.buttons["brake"].tap()
        app.buttons["direction-2"].tap()
        app.buttons["undo"].tap()
        XCTAssertTrue(app.buttons["brake"].isEnabled)
    }
}
