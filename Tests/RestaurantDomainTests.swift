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

    func testPhotoMetadataRoundTripsAndLegacyRecordsStillDecode() throws {
        let withPhoto = Restaurant(
            id: "verona",
            name: "Verona Ristorante",
            category: "Italiana",
            neighborhood: "Asa Sul",
            address: nil,
            phone: nil,
            website: nil,
            rating: nil,
            reviewCount: nil,
            source: "test",
            sourceURL: nil,
            lastVerified: "2026-01-01",
            dataStatus: "verified",
            photoAsset: "VeronaRistorante",
            photoSourceURL: "https://example.com/photo.jpg",
            photoRightsStatus: "user-confirmed-authorized",
            photoAttribution: "Tripadvisor"
        )
        let encoded = try JSONEncoder().encode([withPhoto])
        let decoded = try JSONDecoder().decode([Restaurant].self, from: encoded)
        XCTAssertEqual(decoded.first?.photoAsset, "VeronaRistorante")
        XCTAssertEqual(decoded.first?.photoRightsStatus, "user-confirmed-authorized")
        XCTAssertEqual(decoded.first?.photoAttribution, "Tripadvisor")

        let legacyJSON = Data(#"[{"id":"legacy","name":"Lugar","source":"test","last_verified":"","data_status":"verified"}]"#.utf8)
        let legacy = try XCTUnwrap(JSONDecoder().decode([Restaurant].self, from: legacyJSON).first)
        XCTAssertNil(legacy.photoAsset)
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

    func testCatalogLooksUpRestaurantsByID() {
        let catalog = RestaurantCatalog(data: catalogData([restaurant(id: "one", name: "Casa do Pequi"), restaurant(id: "two")]))
        XCTAssertEqual(catalog.restaurant(withID: "one")?.name, "Casa do Pequi")
        XCTAssertNil(catalog.restaurant(withID: "missing"))
    }

    func testShareTextSummarizesTheRestaurant() {
        let restaurant = Restaurant(id: "one", name: "Casa do Pequi", category: "Brasileira", neighborhood: "Asa Sul", address: "CLS 405", phone: "(61) 3333-0000", website: nil, rating: 4.6, reviewCount: 120, source: "test", sourceURL: nil, lastVerified: "2026-01-01", dataStatus: "verified")
        XCTAssertEqual(
            restaurant.shareText,
            "Casa do Pequi — Brasileira · Asa Sul\nCLS 405\nTel.: (61) 3333-0000\nNota 4,6 no Duo Gourmet\nEncontrado no app Restaurantes Brasília"
        )
    }

    func testBundledCatalogHasNoDuplicateRegionSpellings() {
        let catalog = RestaurantCatalog(bundle: Bundle(for: RestaurantCatalog.self))
        XCTAssertEqual(catalog.loadState, .loaded)
        let neighborhoods = catalog.neighborhoods
        for alias in ["Asa Sul,", "Guará II", "Guará 2", "Taguatinga sul", "Plano Piloto", "SHCS", "SHCN"] {
            XCTAssertFalse(neighborhoods.contains(alias), "Região não normalizada: \(alias)")
        }
    }

    private func restaurant(id: String, name: String = "Lugar", category: String? = nil, neighborhood: String? = nil, address: String? = nil) -> Restaurant {
        Restaurant(id: id, name: name, category: category, neighborhood: neighborhood, address: address, phone: nil, website: nil, rating: nil, reviewCount: 7, source: "test", sourceURL: nil, lastVerified: "2026-01-01", dataStatus: "pending-rights-review")
    }

    private func catalogData(_ restaurants: [Restaurant]) -> Data {
        try! JSONEncoder().encode(restaurants)
    }
}
