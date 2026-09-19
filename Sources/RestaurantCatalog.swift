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
        Self.filter(restaurants, query: query, neighborhood: neighborhood, category: category)
    }

    var topRated: [Restaurant] {
        restaurants.filter(\.hasRating).sorted { $0.qualityScore > $1.qualityScore }
    }

    var mostReviewed: [Restaurant] {
        restaurants.filter { ($0.reviewCount ?? 0) > 0 }.sorted { ($0.reviewCount ?? 0) > ($1.reviewCount ?? 0) }
    }

    var categoryRanking: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: restaurants, by: \.displayCategory).mapValues(\.count)
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    var regionRanking: [(name: String, count: Int)] {
        let counts = Dictionary(grouping: restaurants, by: \.displayNeighborhood).mapValues(\.count)
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    static func filter(_ items: [Restaurant], query: String, neighborhood: String = "Todos", category: String = "Todos") -> [Restaurant] {
        let normalized = query.folding(options: .diacriticInsensitive, locale: .current).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { restaurant in
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
