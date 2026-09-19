import XCTest

final class RestaurantesBrasiliaUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.exists)
    }
}
