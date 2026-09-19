import XCTest
@testable import RestaurantesBrasilia

final class RestaurantDomainTests: XCTestCase {
    func testSearchTextIncludesNameAndNeighborhood() {
        let restaurant = Restaurant(id: "one", name: "Casa do Pequi", category: "Brasileira", neighborhood: "Asa Sul", address: nil, phone: nil, website: nil, rating: nil, reviewCount: nil, source: "test", sourceURL: nil, lastVerified: "2026-01-01", dataStatus: "verified")
        XCTAssertTrue(restaurant.searchableText.contains("casa do pequi"))
        XCTAssertTrue(restaurant.searchableText.contains("asa sul"))
    }

    func testFallbacksAreUseful() {
        let restaurant = Restaurant(id: "one", name: "Lugar", category: nil, neighborhood: nil, address: nil, phone: nil, website: nil, rating: nil, reviewCount: nil, source: "test", sourceURL: nil, lastVerified: "", dataStatus: "verified")
        XCTAssertEqual(restaurant.displayCategory, "Restaurante")
        XCTAssertEqual(restaurant.displayNeighborhood, "Distrito Federal")
    }

    func testWebsiteURLsGetHTTPSWhenSchemeIsMissing() {
        XCTAssertEqual(Restaurant.normalizeWebsiteURL(" example.com/menu ")?.absoluteString, "https://example.com/menu")
        XCTAssertNil(Restaurant.normalizeWebsiteURL("not a website"))
    }

    func testCatalogFiltersBySearchAndSelectors() {
        let catalog = RestaurantCatalog(data: catalogData([
            restaurant(id: "one", name: "Casa do Pequi", category: "Brasileira", neighborhood: "Asa Sul", address: "CLS 10"),
            restaurant(id: "two", name: "Bistrô Norte", category: "Francesa", neighborhood: "Asa Norte", address: "SQN 2")
        ]))

        catalog.query = "pequí"
        XCTAssertEqual(catalog.filtered.map(\.id), ["one"])
        catalog.query = ""
        catalog.neighborhood = "Asa Norte"
        catalog.category = "Francesa"
        XCTAssertEqual(catalog.filtered.map(\.id), ["two"])
    }

    func testCatalogReportsLoadedAndInvalidDataStates() {
        XCTAssertEqual(RestaurantCatalog(data: catalogData([restaurant(id: "one")])).loadState, .loaded)
        XCTAssertEqual(RestaurantCatalog(data: Data("{}".utf8)).loadState, .failed("O catálogo não pôde ser lido."))
        XCTAssertEqual(RestaurantCatalog(data: catalogData([])).loadState, .failed("O catálogo está vazio."))
    }

    func testQualityScoreRewardsReviewVolume() {
        let high = Restaurant(id: "h", name: "A", category: nil, neighborhood: nil, address: nil, phone: nil, website: nil, rating: 4.9, reviewCount: 500, source: "t", sourceURL: nil, lastVerified: "", dataStatus: "verified")
        let low = Restaurant(id: "l", name: "B", category: nil, neighborhood: nil, address: nil, phone: nil, website: nil, rating: 5.0, reviewCount: 1, source: "t", sourceURL: nil, lastVerified: "", dataStatus: "verified")
        XCTAssertTrue(high.qualityScore > low.qualityScore)
    }

    func testTopRatedSortsByQuality() {
        let catalog = RestaurantCatalog(data: catalogData([
            Restaurant(id: "high", name: "A", category: nil, neighborhood: nil, address: nil, phone: nil, website: nil, rating: 4.9, reviewCount: 500, source: "t", sourceURL: nil, lastVerified: "", dataStatus: "verified"),
            Restaurant(id: "low", name: "B", category: nil, neighborhood: nil, address: nil, phone: nil, website: nil, rating: 5.0, reviewCount: 1, source: "t", sourceURL: nil, lastVerified: "", dataStatus: "verified")
        ]))
        XCTAssertEqual(catalog.topRated.first?.id, "high")
    }

    private func restaurant(id: String, name: String = "Lugar", category: String? = nil, neighborhood: String? = nil, address: String? = nil) -> Restaurant {
        Restaurant(id: id, name: name, category: category, neighborhood: neighborhood, address: address, phone: nil, website: nil, rating: nil, reviewCount: 7, source: "test", sourceURL: nil, lastVerified: "2026-01-01", dataStatus: "pending-rights-review")
    }

    private func catalogData(_ restaurants: [Restaurant]) -> Data {
        try! JSONEncoder().encode(restaurants)
    }
}
