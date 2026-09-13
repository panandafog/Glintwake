import XCTest

@MainActor
final class GlintwakeUITests: XCTestCase {
    func testMoveBudgetFailureUndoAndOptimalCompletion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["direction-2"].waitForExistence(timeout: 10))
        for direction in [2, 6, 2] {
            let button = app.buttons["direction-\(direction)"]
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
            waitForExpectations(timeout: 3)
            button.tap()
        }
        XCTAssertTrue(app.staticTexts["exhausted"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["victory"].exists)
        XCTAssertFalse(app.buttons["hint"].isEnabled)
        app.terminate()
        app.launchArguments.append("--keep-test-session")
        app.launch()
        XCTAssertTrue(app.staticTexts["exhausted"].waitForExistence(timeout: 5))
        app.buttons["undo"].tap()
        XCTAssertTrue(app.buttons["direction-2"].waitForExistence(timeout: 3))
        app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["guidance"].label.contains("exceeds the limit"))
        app.buttons["undo"].tap()
        app.buttons["undo"].tap()
        for direction in [2, 4, 6] {
            let button = app.buttons["direction-\(direction)"]
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: button)
            waitForExpectations(timeout: 3)
            button.tap()
        }
        XCTAssertTrue(app.staticTexts["victory"].waitForExistence(timeout: 5))
        app.buttons["difficulty"].tap()
        XCTAssertTrue(app.buttons["mode-easy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["mode-easy"].label.contains("Solved: 1"))
        app.buttons["Done"].tap()
        app.buttons["undo"].tap()
        app.buttons["direction-6"].tap()
        XCTAssertTrue(app.staticTexts["victory"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["victory"].waitForExistence(timeout: 5))
        app.buttons["difficulty"].tap()
        XCTAssertTrue(app.buttons["mode-easy"].label.contains("Solved: 1"))
    }

    func testDifficultySwitchAndSoundPreferencesPersist() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["audio-settings"].waitForExistence(timeout: 10))
        app.buttons["audio-settings"].tap()
        let ambience = app.switches["audio-ambience"]
        XCTAssertTrue(ambience.waitForExistence(timeout: 3))
        // SwiftUI exposes the entire Form row as a switch; tap its trailing control.
        ambience.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(ambience.value as? String, "0")
        XCTAssertEqual(app.switches["audio-effects"].value as? String, "1")
        app.buttons["Done"].tap()
        app.buttons["difficulty"].tap()
        app.buttons["mode-hard"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS 'Hard' AND enabled == true"), evaluatedWith: app.buttons["difficulty"])
        waitForExpectations(timeout: 60)
        XCTAssertTrue(app.buttons["brake"].exists)
        let before = app.descendants(matching: .any).matching(identifier: "board").allElementsBoundByIndex.map(\.label)
        app.terminate()
        app.launchArguments.append("--keep-test-session")
        app.launch()
        XCTAssertTrue(app.buttons["difficulty"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["difficulty"].label.contains("Hard"))
        XCTAssertEqual(before, app.descendants(matching: .any).matching(identifier: "board").allElementsBoundByIndex.map(\.label))
        app.buttons["difficulty"].tap()
        for mode in ["easy", "medium", "hard"] { XCTAssertTrue(app.buttons["mode-\(mode)"].label.contains("Solved: 0")) }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Difficulty and counters"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["other-puzzle"].tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["difficulty"])
        waitForExpectations(timeout: 60)
        XCTAssertTrue(app.buttons["difficulty"].label.contains("Hard"))
        app.buttons["audio-settings"].tap()
        XCTAssertEqual(app.switches["audio-ambience"].value as? String, "0")
        XCTAssertEqual(app.switches["audio-effects"].value as? String, "1")
    }

    func testFixedLayoutRussianLocalizationAndLandscape() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["help"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["help"].label, "Как играть")
        XCTAssertTrue(app.staticTexts["Лимит ходов: 3"].exists)
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
                if id.hasPrefix("direction-") {
                    XCTAssertGreaterThanOrEqual(element.frame.width, 56)
                    XCTAssertGreaterThanOrEqual(element.frame.height, 56)
                }
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
        XCTAssertTrue(app.buttons["direction-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["difficulty"].label.contains("Easy"))
        app.buttons["difficulty"].tap()
        XCTAssertTrue(app.buttons["mode-easy"].label.contains("Solved: 1"))
        app.buttons["mode-medium"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS 'Medium' AND enabled == true"), evaluatedWith: app.buttons["difficulty"])
        waitForExpectations(timeout: 30)
        XCTAssertTrue(app.buttons["brake"].waitForExistence(timeout: 3))
        app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["guidance"].exists)
    }
}
