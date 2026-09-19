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
}
