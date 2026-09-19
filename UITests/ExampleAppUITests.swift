import XCTest

final class RestaurantesBrasiliaUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Sabores da capital"].waitForExistence(timeout: 10))
        capture(app, named: "restaurantes-home")

        let explore = app.tabBars.buttons["Explorar"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        explore.tap()
        XCTAssertTrue(app.navigationBars["Explorar"].waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-explore")
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
