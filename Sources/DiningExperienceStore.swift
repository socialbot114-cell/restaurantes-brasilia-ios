import Foundation
import Combine

struct DiningRoute: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var restaurantIDs: [String]
    let createdAt: Date
}

struct DiningVisit: Codable, Equatable, Identifiable {
    let id: String
    let restaurantID: String
    var visitedAt: Date
    var personalRating: Int
    var note: String
}

final class DiningExperienceStore: ObservableObject {
    @Published private(set) var routes: [DiningRoute] = []
    @Published private(set) var visits: [DiningVisit] = []

    private let defaults: UserDefaults
    private let routesKey = "br.com.restaurantes.bsb.dining-routes.v1"
    private let visitsKey = "br.com.restaurantes.bsb.dining-visits.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        routes = Self.decode([DiningRoute].self, from: defaults.data(forKey: routesKey)) ?? []
        visits = Self.decode([DiningVisit].self, from: defaults.data(forKey: visitsKey)) ?? []
    }

    @discardableResult
    func createRoute(name: String) -> DiningRoute? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let route = DiningRoute(id: UUID().uuidString, name: cleanName, restaurantIDs: [], createdAt: Date())
        routes.insert(route, at: 0)
        saveRoutes()
        return route
    }

    func route(withID id: String) -> DiningRoute? {
        routes.first { $0.id == id }
    }

    func deleteRoute(_ routeID: String) {
        routes.removeAll { $0.id == routeID }
        saveRoutes()
    }

    @discardableResult
    func addRestaurant(_ restaurantID: String, to routeID: String) -> Bool {
        guard let index = routes.firstIndex(where: { $0.id == routeID }),
              !routes[index].restaurantIDs.contains(restaurantID) else { return false }
        routes[index].restaurantIDs.append(restaurantID)
        saveRoutes()
        return true
    }

    func removeRestaurant(_ restaurantID: String, from routeID: String) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        routes[index].restaurantIDs.removeAll { $0 == restaurantID }
        saveRoutes()
    }

    func moveRestaurants(in routeID: String, from source: IndexSet, to destination: Int) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        var orderedIDs = routes[index].restaurantIDs
        let validOffsets = source.sorted().filter(orderedIDs.indices.contains)
        guard !validOffsets.isEmpty else { return }
        let moving = validOffsets.map { orderedIDs[$0] }
        for offset in validOffsets.reversed() {
            orderedIDs.remove(at: offset)
        }
        let adjustedDestination = max(0, min(destination - validOffsets.filter { $0 < destination }.count, orderedIDs.count))
        orderedIDs.insert(contentsOf: moving, at: adjustedDestination)
        routes[index].restaurantIDs = orderedIDs
        saveRoutes()
    }

    @discardableResult
    func recordVisit(
        restaurantID: String,
        visitedAt: Date = Date(),
        personalRating: Int,
        note: String
    ) -> DiningVisit {
        let visit = DiningVisit(
            id: UUID().uuidString,
            restaurantID: restaurantID,
            visitedAt: visitedAt,
            personalRating: min(5, max(1, personalRating)),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        visits.insert(visit, at: 0)
        saveVisits()
        return visit
    }

    func deleteVisit(_ visitID: String) {
        visits.removeAll { $0.id == visitID }
        saveVisits()
    }

    func contains(_ restaurantID: String, in routeID: String) -> Bool {
        route(withID: routeID)?.restaurantIDs.contains(restaurantID) ?? false
    }

    func visits(for restaurantID: String) -> [DiningVisit] {
        visits.filter { $0.restaurantID == restaurantID }.sorted { $0.visitedAt > $1.visitedAt }
    }

    private func saveRoutes() {
        defaults.set(try? JSONEncoder().encode(routes), forKey: routesKey)
    }

    private func saveVisits() {
        defaults.set(try? JSONEncoder().encode(visits), forKey: visitsKey)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
