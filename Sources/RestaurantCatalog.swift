import Foundation
import Combine

final class RestaurantCatalog: ObservableObject {
    @Published private(set) var restaurants: [Restaurant] = []
    @Published var query = ""
    @Published var neighborhood = "Todos"
    @Published var category = "Todos"

    init() {
        load()
    }

    var neighborhoods: [String] {
        ["Todos"] + Set(restaurants.map(\.displayNeighborhood)).sorted()
    }

    var categories: [String] {
        ["Todos"] + Set(restaurants.map(\.displayCategory)).sorted()
    }

    var filtered: [Restaurant] {
        let normalized = query.folding(options: .diacriticInsensitive, locale: .current).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return restaurants.filter { restaurant in
            (normalized.isEmpty || restaurant.searchableText.contains(normalized)) &&
                (neighborhood == "Todos" || restaurant.displayNeighborhood == neighborhood) &&
                (category == "Todos" || restaurant.displayCategory == category)
        }
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "Catalog"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Restaurant].self, from: data) else { return }
        restaurants = decoded
    }
}
