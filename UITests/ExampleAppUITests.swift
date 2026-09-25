import XCTest

final class RestaurantesBrasiliaUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Qual é a sua fome hoje?"].waitForExistence(timeout: 10))
        capture(app, named: "restaurantes-home")

        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'hero-'")).firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.tap()
        capture(app, named: "restaurantes-detalhe")
        app.buttons["record-visit"].tap()
        XCTAssertTrue(app.buttons["save-visit"].waitForExistence(timeout: 5))
        app.buttons["save-visit"].tap()
        XCTAssertTrue(app.staticTexts["Meu diário"].waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-diario")
        app.navigationBars.buttons.firstMatch.tap()

        let search = app.textFields["restaurant-search-field"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Verona\n")
        let verona = app.descendants(matching: .any)
            .matching(identifier: "row-duogourmet-verona-ristorante")
            .firstMatch
        XCTAssertTrue(verona.waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-verona-busca")

        tapTab(app, "Explorar")
        XCTAssertTrue(app.navigationBars["Explorar"].waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-explore")

        let add = app.buttons["Adicionar aos favoritos"].firstMatch
        if add.waitForExistence(timeout: 3) {
            add.tap()
        }
        tapTab(app, "Salvos")
        capture(app, named: "restaurantes-favoritos")

        tapTab(app, "Roteiros")
        XCTAssertTrue(app.navigationBars["Roteiros"].waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-roteiros-vazio")

        let createRoute = app.buttons["create-route-empty"].waitForExistence(timeout: 2)
            ? app.buttons["create-route-empty"]
            : app.buttons["create-route"]
        XCTAssertTrue(createRoute.waitForExistence(timeout: 5))
        createRoute.tap()
        let routeName = app.textFields["route-name-field"]
        XCTAssertTrue(routeName.waitForExistence(timeout: 5))
        routeName.tap()
        routeName.typeText("Sabores do DF")
        app.buttons["save-route"].tap()

        let routeLink = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'route-'" )).firstMatch
        XCTAssertTrue(routeLink.waitForExistence(timeout: 5))
        routeLink.tap()
        app.buttons["add-restaurants"].tap()
        let firstRestaurant = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'add-restaurant-'" )).firstMatch
        XCTAssertTrue(firstRestaurant.waitForExistence(timeout: 5))
        firstRestaurant.tap()
        app.buttons["done-adding-restaurants"].tap()
        let plannedRestaurant = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'route-restaurant-'"))
            .firstMatch
        XCTAssertTrue(plannedRestaurant.waitForExistence(timeout: 5))
        capture(app, named: "restaurantes-roteiro-planejado")

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
