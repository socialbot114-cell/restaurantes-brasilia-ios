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

        tapTab(app, "Explorar")
        XCTAssertTrue(app.navigationBars["Explorar"].waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-explore")

        let add = app.buttons["Adicionar aos favoritos"].firstMatch
        if add.waitForExistence(timeout: 3) {
            add.tap()
        }
        tapTab(app, "Salvos")
        capture(app, named: "restaurantes-favoritos")
    }

    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.waitForExistence(timeout: 2) {
            tabBarButton.tap()
            return
        }
        let button = app.buttons[name].firstMatch
        if button.waitForExistence(timeout: 3) {
            button.tap()
        }
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
