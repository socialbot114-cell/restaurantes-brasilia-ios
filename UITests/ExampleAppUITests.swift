import XCTest

final class RestaurantesBrasiliaUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Qual é a sua fome hoje?"].waitForExistence(timeout: 10))
        capture(app, named: "restaurantes-home")

        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'hero-'")).firstMatch
        if firstCard.waitForExistence(timeout: 5) {
            firstCard.tap()
            capture(app, named: "restaurantes-detalhe")
            app.navigationBars.buttons.firstMatch.tap()
        }

        let explore = app.tabBars.buttons["Explorar"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        explore.tap()
        XCTAssertTrue(app.navigationBars["Explorar"].waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-explore")

        let add = app.buttons["Adicionar aos favoritos"].firstMatch
        if add.waitForExistence(timeout: 3) {
            add.tap()
        }
        let saved = app.tabBars.buttons["Salvos"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        capture(app, named: "restaurantes-favoritos")
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
