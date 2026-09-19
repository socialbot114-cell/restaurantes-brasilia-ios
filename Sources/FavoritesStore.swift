import Foundation
import Combine

final class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<String>
    private let key = "favorite-restaurant-ids"

    init() {
        ids = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
