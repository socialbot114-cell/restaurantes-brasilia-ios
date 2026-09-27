import XCTest

final class PhotoVisualReviewUITests: XCTestCase {
    func testPhotoVisualReview() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Qual é a sua fome hoje?"].waitForExistence(timeout: 10))
        capture(app, named: "01-home")

        enterSearch("313 Drink Bar", in: app)
        let duoRow = app.descendants(matching: .any)
            .matching(identifier: "row-duogourmet-313-drink-bar")
            .firstMatch
        XCTAssertTrue(duoRow.waitForExistence(timeout: 10))
        let duoArtwork = app.descendants(matching: .any)
            .matching(identifier: "restaurant-artwork-duogourmet-313-drink-bar")
            .firstMatch
        XCTAssertTrue(duoArtwork.waitForExistence(timeout: 5), "The search result should expose its restaurant photo.")
        capture(app, named: "02-home-search-results")

        let favorite = app.buttons["Adicionar aos favoritos"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        duoRow.tap()

        XCTAssertTrue(app.staticTexts["Foto: Duo Gourmet"].waitForExistence(timeout: 10))
        let duoPhoto = app.descendants(matching: .any)
            .matching(identifier: "restaurant-photo-duogourmet-313-drink-bar")
            .firstMatch
        XCTAssertTrue(duoPhoto.waitForExistence(timeout: 5), "The Duo Gourmet photo should appear on the detail screen.")
        capture(app, named: "03-duo-gourmet-detail")

        tapTab(app, named: "Explorar")
        XCTAssertTrue(app.navigationBars["Explorar"].waitForExistence(timeout: 5))
        capture(app, named: "04-explore-photo-list")

        enterSearch("Verona", in: app)
        let veronaRow = app.descendants(matching: .any)
            .matching(identifier: "explore-row-duogourmet-verona-ristorante")
            .firstMatch
        XCTAssertTrue(veronaRow.waitForExistence(timeout: 10))
        capture(app, named: "05-explore-search-results")
        veronaRow.tap()

        XCTAssertTrue(app.staticTexts["Foto: Tripadvisor"].waitForExistence(timeout: 10))
        let veronaPhoto = app.descendants(matching: .any)
            .matching(identifier: "restaurant-photo-duogourmet-verona-ristorante")
            .firstMatch
        XCTAssertTrue(veronaPhoto.waitForExistence(timeout: 5))
        capture(app, named: "06-tripadvisor-photo-detail")

        tapTab(app, named: "Salvos")
        XCTAssertTrue(app.navigationBars["Salvos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["313 Drink Bar"].waitForExistence(timeout: 5))
        capture(app, named: "07-favorites-with-photo")
    }

    private func enterSearch(_ query: String, in app: XCUIApplication) {
        let search = app.textFields["restaurant-search-field"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("\(query)\n")
    }

    private func tapTab(_ app: XCUIApplication, named name: String) {
        let tab = app.tabBars.buttons[name].firstMatch
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
            return
        }

        let button = app.buttons[name].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Expected to find the \(name) tab.")
        button.tap()
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
