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
    @Published private(set) var storageRecoveryNotice: String?

    private let defaults: UserDefaults
    static let routesKey = "br.com.restaurantes.bsb.dining-routes.v1"
    static let visitsKey = "br.com.restaurantes.bsb.dining-visits.v1"
    static let routesRecoveryBackupKey = "br.com.restaurantes.bsb.dining-routes.corrupt-backups.v1"
    static let visitsRecoveryBackupKey = "br.com.restaurantes.bsb.dining-visits.corrupt-backups.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var affectedSections: [String] = []
        let routesData = defaults.data(forKey: Self.routesKey)
        if let decodedRoutes = Self.decode(
            [DiningRoute].self,
            from: routesData,
            preservingInvalidDataIn: defaults,
            backupKey: Self.routesRecoveryBackupKey
        ) {
            routes = decodedRoutes
        } else {
            routes = []
            if routesData != nil { affectedSections.append("roteiros") }
        }

        let visitsData = defaults.data(forKey: Self.visitsKey)
        if let decodedVisits = Self.decode(
            [DiningVisit].self,
            from: visitsData,
            preservingInvalidDataIn: defaults,
            backupKey: Self.visitsRecoveryBackupKey
        ) {
            visits = decodedVisits
        } else {
            visits = []
            if visitsData != nil { affectedSections.append("visitas") }
        }

        if !affectedSections.isEmpty {
            let sectionNames = affectedSections.count == 2
                ? "\(affectedSections[0]) e \(affectedSections[1])"
                : affectedSections[0]
            storageRecoveryNotice = "O app encontrou dados de \(sectionNames) que não conseguiu ler. Uma cópia original foi preservada; a área afetada será iniciada vazia. Você pode continuar usando o app."
        }
    }

    func dismissStorageRecoveryNotice() {
        storageRecoveryNotice = nil
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

    @discardableResult
    func renameRoute(_ routeID: String, to name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, let index = routes.firstIndex(where: { $0.id == routeID }) else { return false }
        var updatedRoutes = routes
        updatedRoutes[index].name = cleanName
        routes = updatedRoutes
        saveRoutes()
        return true
    }

    func deleteRoute(_ routeID: String) {
        routes.removeAll { $0.id == routeID }
        saveRoutes()
    }

    @discardableResult
    func addRestaurant(_ restaurantID: String, to routeID: String) -> Bool {
        guard let index = routes.firstIndex(where: { $0.id == routeID }),
              !routes[index].restaurantIDs.contains(restaurantID) else { return false }
        var updatedRoutes = routes
        updatedRoutes[index].restaurantIDs.append(restaurantID)
        routes = updatedRoutes
        saveRoutes()
        return true
    }

    func removeRestaurant(_ restaurantID: String, from routeID: String) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        var updatedRoutes = routes
        updatedRoutes[index].restaurantIDs.removeAll { $0 == restaurantID }
        routes = updatedRoutes
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
        var updatedRoutes = routes
        updatedRoutes[index].restaurantIDs = orderedIDs
        routes = updatedRoutes
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

    /// Restaurant IDs with at least one visit, most recently visited first.
    var visitedRestaurantIDs: [String] {
        var latest: [String: Date] = [:]
        for visit in visits where visit.visitedAt > (latest[visit.restaurantID] ?? .distantPast) {
            latest[visit.restaurantID] = visit.visitedAt
        }
        return latest.sorted { $0.value > $1.value }.map(\.key)
    }

    private func saveRoutes() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        defaults.set(data, forKey: Self.routesKey)
    }

    private func saveVisits() {
        guard let data = try? JSONEncoder().encode(visits) else { return }
        defaults.set(data, forKey: Self.visitsKey)
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data?,
        preservingInvalidDataIn defaults: UserDefaults,
        backupKey: String
    ) -> Value? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            var backups = defaults.array(forKey: backupKey) as? [Data] ?? []
            if !backups.contains(data) {
                backups.append(data)
                defaults.set(backups, forKey: backupKey)
            }
            return nil
        }
    }
}
