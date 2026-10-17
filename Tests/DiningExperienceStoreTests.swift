import XCTest
@testable import RestaurantesBrasilia

final class DiningExperienceStoreTests: XCTestCase {
    func testRoutePlanningIsDeduplicatedReorderableAndPersistent() throws {
        let defaults = makeDefaults()
        let store = DiningExperienceStore(defaults: defaults)
        let route = try XCTUnwrap(store.createRoute(name: "  Sábado em Brasília  "))

        XCTAssertEqual(route.name, "Sábado em Brasília")
        XCTAssertTrue(store.addRestaurant("restaurant-a", to: route.id))
        XCTAssertTrue(store.addRestaurant("restaurant-b", to: route.id))
        XCTAssertFalse(store.addRestaurant("restaurant-a", to: route.id))
        store.moveRestaurants(in: route.id, from: IndexSet(integer: 0), to: 2)

        let restored = DiningExperienceStore(defaults: defaults)
        XCTAssertEqual(restored.route(withID: route.id)?.restaurantIDs, ["restaurant-b", "restaurant-a"])
    }

    func testVisitRatingAndNoteAreNormalizedAndPersisted() throws {
        let defaults = makeDefaults()
        let store = DiningExperienceStore(defaults: defaults)
        let visit = store.recordVisit(restaurantID: "restaurant-a", personalRating: 8, note: "  Adorei o jantar.  ")

        XCTAssertEqual(visit.personalRating, 5)
        XCTAssertEqual(visit.note, "Adorei o jantar.")
        XCTAssertEqual(DiningExperienceStore(defaults: defaults).visits(for: "restaurant-a"), [visit])
    }

    func testBlankRouteNamesAreRejected() {
        XCTAssertNil(DiningExperienceStore(defaults: makeDefaults()).createRoute(name: " \n "))
    }

    func testRoutesCanBeRenamedButNotBlanked() throws {
        let defaults = makeDefaults()
        let store = DiningExperienceStore(defaults: defaults)
        let route = try XCTUnwrap(store.createRoute(name: "Sábado"))

        XCTAssertTrue(store.renameRoute(route.id, to: "  Domingo no Lago  "))
        XCTAssertFalse(store.renameRoute(route.id, to: "   "))
        XCTAssertFalse(store.renameRoute("missing", to: "Outro"))
        XCTAssertEqual(DiningExperienceStore(defaults: defaults).route(withID: route.id)?.name, "Domingo no Lago")
    }

    func testVisitedRestaurantsAreOrderedByLatestVisit() {
        let store = DiningExperienceStore(defaults: makeDefaults())
        let now = Date()
        store.recordVisit(restaurantID: "a", visitedAt: now.addingTimeInterval(-300), personalRating: 4, note: "")
        store.recordVisit(restaurantID: "b", visitedAt: now.addingTimeInterval(-200), personalRating: 3, note: "")
        store.recordVisit(restaurantID: "a", visitedAt: now, personalRating: 5, note: "")

        XCTAssertEqual(store.visitedRestaurantIDs, ["a", "b"])
    }

    func testCorruptRoutesArePreservedBeforeNewDataCanOverwriteThem() throws {
        let defaults = makeDefaults()
        let corruptData = Data("not valid json".utf8)
        defaults.set(corruptData, forKey: DiningExperienceStore.routesKey)

        let store = DiningExperienceStore(defaults: defaults)

        XCTAssertTrue(store.routes.isEmpty)
        XCTAssertEqual(defaults.data(forKey: DiningExperienceStore.routesKey), corruptData)
        XCTAssertEqual(defaults.array(forKey: DiningExperienceStore.routesRecoveryBackupKey) as? [Data], [corruptData])
        XCTAssertTrue(store.storageRecoveryNotice?.contains("roteiros") == true)

        XCTAssertNotNil(store.createRoute(name: "Novo roteiro"))
        XCTAssertNotEqual(defaults.data(forKey: DiningExperienceStore.routesKey), corruptData)
        XCTAssertEqual(defaults.array(forKey: DiningExperienceStore.routesRecoveryBackupKey) as? [Data], [corruptData])
    }

    func testCorruptVisitsDoNotPreventValidRoutesFromLoading() throws {
        let defaults = makeDefaults()
        let route = DiningRoute(id: "route-a", name: "Sábado", restaurantIDs: ["restaurant-a"], createdAt: Date())
        defaults.set(try JSONEncoder().encode([route]), forKey: DiningExperienceStore.routesKey)
        let corruptData = Data("{".utf8)
        defaults.set(corruptData, forKey: DiningExperienceStore.visitsKey)

        let store = DiningExperienceStore(defaults: defaults)

        XCTAssertEqual(store.routes, [route])
        XCTAssertTrue(store.visits.isEmpty)
        XCTAssertEqual(defaults.array(forKey: DiningExperienceStore.visitsRecoveryBackupKey) as? [Data], [corruptData])
        XCTAssertTrue(store.storageRecoveryNotice?.contains("visitas") == true)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "DiningExperienceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
