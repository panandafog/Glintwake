import XCTest

/// Opt-in capture adapter, excluded from the ordinary Glintwake test scheme.
@MainActor
final class StoreScreenshots: XCTestCase {
    func test01Gameplay() throws { try capture("gameplay") }
    func test02Planning() throws { try capture("planning") }
    func test03Difficulty() throws { try capture("difficulty") }
    func test04Victory() throws { try capture("victory") }

    private func capture(_ scene: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-scene=" + scene]
        app.launch()
        defer { app.terminate() }
        let marker = app.descendants(matching: .any).matching(identifier: "screen." + scene).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 20), "Scene not ready: " + scene)
        #if os(macOS)
        let window = app.windows.firstMatch
        let sized = NSPredicate { _, _ in
            abs(window.frame.width - 1280) < 1 && abs(window.frame.height - 800) < 1
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: sized, object: nil)], timeout: 10), .completed)
        let screenshot = window.screenshot()
        #else
        let screenshot = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "framepilot-" + scene
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
