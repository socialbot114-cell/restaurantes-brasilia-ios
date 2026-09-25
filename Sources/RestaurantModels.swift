import Foundation

struct Restaurant: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
    let neighborhood: String?
    let address: String?
    let phone: String?
    let website: String?
    let rating: Double?
    let reviewCount: Int?
    let source: String
    let sourceURL: String?
    let lastVerified: String
    let dataStatus: String
    var photoAsset: String? = nil
    var photoSourceURL: String? = nil
    var photoRightsStatus: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, category, neighborhood, address, phone, website, rating
        case reviewCount = "review_count"
        case source
        case sourceURL = "source_url"
        case lastVerified = "last_verified"
        case dataStatus = "data_status"
        case photoAsset = "photo_asset"
        case photoSourceURL = "photo_source_url"
        case photoRightsStatus = "photo_rights_status"
    }

    var displayCategory: String { category?.nilIfEmpty ?? "Restaurante" }
    var displayNeighborhood: String { neighborhood?.nilIfEmpty ?? "Distrito Federal" }
    var normalizedWebsiteURL: URL? { Self.normalizeWebsiteURL(website) }
    var hasRating: Bool { rating != nil && (reviewCount ?? 0) > 0 }
    var qualityScore: Double {
        guard let rating else { return 0 }
        let reviews = Double(reviewCount ?? 0)
        let prior = 4.0
        let priorWeight = 20.0
        return (rating * reviews + prior * priorWeight) / (reviews + priorWeight)
    }
    var searchableText: String {
        [name, displayCategory, displayNeighborhood, address ?? ""].joined(separator: " ").folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }

    static func normalizeWebsiteURL(_ value: String?) -> URL? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else { return nil }
        return components.url
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
