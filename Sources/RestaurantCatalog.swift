import Foundation
import Combine

enum CatalogLoadState: Equatable {
    case loading
    case loaded
    case failed(String)
}

final class RestaurantCatalog: ObservableObject {
    @Published private(set) var restaurants: [Restaurant] = []
    @Published private(set) var loadState: CatalogLoadState = .loading
    @Published var query = ""
    @Published var neighborhood = "Todos"
    @Published var category = "Todos"

    init(bundle: Bundle = .main) {
        load(bundle: bundle)
    }

    init(data: Data) {
        load(data: data)
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

    private func load(bundle: Bundle) {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json", subdirectory: "Catalog"),
              let data = try? Data(contentsOf: url) else {
            loadState = .failed("Não foi possível carregar o catálogo.")
            return
        }
        load(data: data)
    }

    private func load(data: Data) {
        guard let decoded = try? JSONDecoder().decode([Restaurant].self, from: data) else {
            loadState = .failed("O catálogo não pôde ser lido.")
            return
        }
        guard decoded.isEmpty == false else {
            loadState = .failed("O catálogo está vazio.")
            return
        }
        restaurants = decoded
        loadState = .loaded
    }
}
