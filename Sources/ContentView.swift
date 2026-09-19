import SwiftUI

struct ContentView: View {
    @StateObject private var catalog = RestaurantCatalog()
    @StateObject private var favorites = FavoritesStore()

    var body: some View {
        TabView {
            HomeView(catalog: catalog, favorites: favorites)
                .tabItem { Label("Início", systemImage: "house") }
            ExploreView(catalog: catalog, favorites: favorites)
                .tabItem { Label("Explorar", systemImage: "magnifyingglass") }
            FavoritesView(catalog: catalog, favorites: favorites)
                .tabItem { Label("Salvos", systemImage: "heart") }
        }
        .tint(Theme.forest)
    }
}

// MARK: - Home

private struct HomeView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore
    @State private var query = ""
    @State private var selectedCategory: String?

    private let intents: [(label: String, category: String)] = [
        ("Café", "Cafeteria"),
        ("Pizza", "Pizzaria"),
        ("Hambúrguer", "Hamburgueria"),
        ("Japonesa", "Japonesa"),
        ("Brasileira", "Brasileira"),
        ("Doces", "Doces"),
        ("Saudável", "Saudável"),
        ("Italiana", "Italiana")
    ]

    private var isBrowsing: Bool { !query.isEmpty || selectedCategory != nil }

    private var results: [Restaurant] {
        var items = RestaurantCatalog.filter(catalog.restaurants, query: query, category: selectedCategory ?? "Todos")
        items.sort { $0.qualityScore > $1.qualityScore }
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    SearchBar(text: $query, placeholder: "Restaurante, categoria ou região")

                    if catalog.loadState == .failed {
                        CatalogStatusView(state: catalog.loadState)
                    } else if isBrowsing {
                        browsingResults
                    } else {
                        discovery
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.canvas)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.forest).frame(width: 36, height: 36)
                    Image(systemName: "fork.knife").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ipe)
                }
                Text("BRASÍLIA À MESA")
                    .font(.caption.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Theme.terracotta)
            }
            Text("Qual é a sua fome hoje?")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Um guia para escolher onde comer pelas quadras e regiões do DF.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var browsingResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let category = selectedCategory { Text(category).font(.title3.bold()) }
                else { Text("Resultados").font(.title3.bold()) }
                Spacer()
                Button("Limpar") { query = ""; selectedCategory = nil }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
            }
            Text("\(results.count) lugar\(results.count == 1 ? "" : "es")")
                .font(.footnote).foregroundStyle(.secondary)

            if results.isEmpty {
                ContentUnavailableView("Nada por aqui", systemImage: "fork.knife", description: Text("Tente outra busca ou categoria."))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(results) { restaurant in
                        restaurantRow(restaurant)
                    }
                }
            }
        }
    }

    private var discovery: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("O que você quer hoje?").font(.title3.bold()); Spacer() }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(intents, id: \.category) { intent in
                            intentChip(intent)
                        }
                    }
                }
            }

            if !catalog.topRated.isEmpty {
                collection(title: "Boas apostas", subtitle: "Nota e avaliações equilibradas", items: Array(catalog.topRated.prefix(8)))
            }
            if !catalog.mostReviewed.isEmpty {
                collection(title: "Muito comentados", subtitle: "Os mais avaliados em Brasília", items: Array(catalog.mostReviewed.prefix(8)))
            }

            cuisineGrid
        }
    }

    private func intentChip(_ intent: (label: String, category: String)) -> some View {
        let style = CuisineStyle.identity(for: intent.category)
        return Button {
            selectedCategory = intent.category
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(style.tint.opacity(0.16)).frame(width: 56, height: 56)
                    Image(systemName: style.symbol).font(.system(size: 22)).foregroundStyle(style.tint)
                }
                Text(intent.label).font(.caption.weight(.semibold)).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func collection(title: String, subtitle: String, items: [Restaurant]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, restaurant in
                        NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites) } label: {
                            HeroCard(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("hero-\(index)")
                    }
                }
            }
        }
    }

    private var cuisineGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explorar por cozinha").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(catalog.categoryRanking.prefix(8), id: \.name) { item in
                    let style = CuisineStyle.identity(for: item.name)
                    Button {
                        selectedCategory = item.name
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(style.tint.opacity(0.14)).frame(height: 64)
                                Image(systemName: style.symbol).font(.system(size: 26)).foregroundStyle(style.tint)
                            }
                            Text(item.name).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                            Text("\(item.count)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func restaurantRow(_ restaurant: Restaurant) -> some View {
        HStack(spacing: 10) {
            NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites) } label: {
                RestaurantCard(restaurant: restaurant, showFavorite: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("row-\(restaurant.id)")
            FavoriteButton(restaurant: restaurant, favorites: favorites)
        }
    }
}

// MARK: - Explore

private enum RestaurantSort: String, CaseIterable, Identifiable {
    case topRated = "Melhores"
    case mostReviewed = "Mais avaliados"
    case alphabetical = "A–Z"
    var id: String { rawValue }
}

private struct ExploreView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore
    @State private var sort: RestaurantSort = .topRated
    @State private var showRegion = false
    @State private var showCategory = false

    private var results: [Restaurant] {
        switch sort {
        case .topRated: return catalog.filtered.sorted { $0.qualityScore > $1.qualityScore }
        case .mostReviewed: return catalog.filtered.sorted { ($0.reviewCount ?? 0) > ($1.reviewCount ?? 0) }
        case .alphabetical: return catalog.filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var hasFilters: Bool {
        catalog.query.isEmpty == false || catalog.neighborhood != "Todos" || catalog.category != "Todos"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SearchBar(text: $catalog.query, placeholder: "Restaurante, categoria ou região")

                    filterChips

                    Text("\(results.count) lugar\(results.count == 1 ? "" : "es")")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if catalog.loadState == .failed {
                        CatalogStatusView(state: catalog.loadState)
                    } else if results.isEmpty {
                        ContentUnavailableView("Nenhum resultado", systemImage: "magnifyingglass", description: Text("Ajuste a busca ou limpe os filtros."))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(results) { restaurant in
                                HStack(spacing: 10) {
                                    NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites) } label: {
                                        RestaurantCard(restaurant: restaurant, showFavorite: false)
                                    }
                                    .buttonStyle(.plain)
                                    FavoriteButton(restaurant: restaurant, favorites: favorites)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Theme.canvas)
            .navigationTitle("Explorar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Ordenar", selection: $sort) {
                            ForEach(RestaurantSort.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Ordenar", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showRegion) {
                OptionPicker(title: "Região", options: catalog.neighborhoods, selection: $catalog.neighborhood)
            }
            .sheet(isPresented: $showCategory) {
                OptionPicker(title: "Cozinha", options: catalog.categories, selection: $catalog.category)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: catalog.neighborhood == "Todos" ? "Região" : catalog.neighborhood, active: catalog.neighborhood != "Todos") { showRegion = true }
                chip(title: catalog.category == "Todos" ? "Cozinha" : catalog.category, active: catalog.category != "Todos") { showCategory = true }
                if hasFilters {
                    Button {
                        catalog.query = ""; catalog.neighborhood = "Todos"; catalog.category = "Todos"
                    } label: {
                        Label("Limpar", systemImage: "xmark").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.terracotta.opacity(0.14), in: Capsule()).foregroundStyle(Theme.terracotta)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(active ? Theme.forest : Theme.softSurface, in: Capsule())
                .foregroundStyle(active ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Favorites

private struct FavoritesView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        NavigationStack {
            Group {
                let saved = catalog.restaurants.filter { favorites.contains($0.id) }
                if saved.isEmpty {
                    ContentUnavailableView {
                        Label("Nada salvo ainda", systemImage: "heart")
                    } description: {
                        Text("Toque no coração de um restaurante para guardá-lo aqui.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(saved) { restaurant in
                                HStack(spacing: 10) {
                                    NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites) } label: {
                                        RestaurantCard(restaurant: restaurant, showFavorite: false)
                                    }
                                    .buttonStyle(.plain)
                                    FavoriteButton(restaurant: restaurant, favorites: favorites)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Salvos")
        }
    }
}

// MARK: - Detail

private struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @ObservedObject var favorites: FavoritesStore
    @Environment(\.openURL) private var openURL

    private var style: CuisineStyle.Identity { CuisineStyle.identity(for: restaurant.displayCategory) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero

                VStack(alignment: .leading, spacing: 6) {
                    Text(restaurant.name).font(.system(size: 28, weight: .bold, design: .serif))
                    HStack(spacing: 8) {
                        categoryBadge
                        Text(restaurant.displayNeighborhood).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                if restaurant.hasRating { ratingRow }
                if let address = restaurant.address, !address.isEmpty { addressRow(address) }

                actions

                provenance
            }
            .padding()
        }
        .background(Theme.canvas)
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { favorites.toggle(restaurant.id) } label: {
                    Image(systemName: favorites.contains(restaurant.id) ? "heart.fill" : "heart")
                        .foregroundStyle(Theme.terracotta)
                }
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [style.tint, Theme.forestDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 200)
            Image(systemName: style.symbol)
                .font(.system(size: 84))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
            Text(restaurant.displayCategory)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(16)
        }
        .accessibilityLabel("Categoria \(restaurant.displayCategory)")
    }

    private var categoryBadge: some View {
        Text(restaurant.displayCategory)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(style.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(style.tint)
    }

    private var ratingRow: some View {
        HStack(spacing: 14) {
            Label(String(format: "%.1f", restaurant.rating ?? 0), systemImage: "star.fill").foregroundStyle(Theme.ipe)
            if let count = restaurant.reviewCount {
                Text("\(compactCount(count)) avaliações").foregroundStyle(.secondary)
            }
            Spacer()
            Text("Duo Gourmet").font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func addressRow(_ address: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(style.tint)
            Text(address).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            let query = restaurant.address ?? "\(restaurant.name), Brasília DF"
            if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Brasilia")") {
                PrimaryAction(title: "Como chegar", systemImage: "map", url: url, openURL: openURL)
            }
            if let phone = restaurant.phone, let url = URL(string: "tel:\(phone.filter { $0.isNumber })") {
                SecondaryAction(title: "Ligar", systemImage: "phone", url: url, openURL: openURL)
            }
            if let url = restaurant.normalizedWebsiteURL {
                SecondaryAction(title: "Ver no Duo Gourmet", systemImage: "safari", url: url, openURL: openURL)
            }
        }
    }

    private var provenance: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text("Dados consultados em \(displayDate(restaurant.lastVerified)) via Duo Gourmet. Confirme horários e informações diretamente com o estabelecimento.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Theme.softSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Components

private struct RestaurantCard: View {
    let restaurant: Restaurant
    var showFavorite: Bool = false

    private var style: CuisineStyle.Identity { CuisineStyle.identity(for: restaurant.displayCategory) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(style.tint.opacity(0.16)).frame(width: 60, height: 60)
                Image(systemName: style.symbol).font(.system(size: 24)).foregroundStyle(style.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(restaurant.displayCategory).font(.caption).foregroundStyle(style.tint)
                    Text("·").foregroundStyle(.secondary)
                    Text(restaurant.displayNeighborhood).font(.caption).foregroundStyle(.secondary)
                }
                if restaurant.hasRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.ipe)
                        Text(String(format: "%.1f", restaurant.rating ?? 0)).font(.caption.weight(.semibold))
                        if let count = restaurant.reviewCount { Text("(\(compactCount(count)))").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary.opacity(0.6)))
    }
}

private struct HeroCard: View {
    let restaurant: Restaurant
    private var style: CuisineStyle.Identity { CuisineStyle.identity(for: restaurant.displayCategory) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [style.tint, style.tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 110)
                Image(systemName: style.symbol).font(.system(size: 40)).foregroundStyle(.white.opacity(0.95))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name).font(.subheadline.weight(.bold)).foregroundStyle(.primary).lineLimit(1)
                Text(restaurant.displayNeighborhood).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if restaurant.hasRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.ipe)
                        Text(String(format: "%.1f", restaurant.rating ?? 0)).font(.caption.weight(.semibold))
                        if let count = restaurant.reviewCount { Text("· \(compactCount(count))").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .frame(width: 180)
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary.opacity(0.6)))
    }
}

private struct FavoriteButton: View {
    let restaurant: Restaurant
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        Button {
            favorites.toggle(restaurant.id)
        } label: {
            Image(systemName: favorites.contains(restaurant.id) ? "heart.fill" : "heart")
                .font(.system(size: 18))
                .foregroundStyle(favorites.contains(restaurant.id) ? Theme.terracotta : .secondary)
                .frame(width: 40, height: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(favorites.contains(restaurant.id) ? "Remover dos favoritos" : "Adicionar aos favoritos")
    }
}

private struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text).textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary.opacity(0.6)))
    }
}

private struct OptionPicker: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        let normalized = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        guard !normalized.isEmpty else { return options }
        return options.filter { $0.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(normalized) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    HStack {
                        Text(option).foregroundStyle(.primary)
                        Spacer()
                        if option == selection { Image(systemName: "checkmark").foregroundStyle(Theme.forest) }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar")
        }
    }
}

private struct PrimaryAction: View {
    let title: String
    let systemImage: String
    let url: URL
    let openURL: OpenURLAction

    var body: some View {
        Button { openURL(url) } label: {
            Label(title, systemImage: systemImage).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.forest)
    }
}

private struct SecondaryAction: View {
    let title: String
    let systemImage: String
    let url: URL
    let openURL: OpenURLAction

    var body: some View {
        Button { openURL(url) } label: {
            Label(title, systemImage: systemImage).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(Theme.forest)
    }
}

private struct CatalogStatusView: View {
    let state: CatalogLoadState
    var body: some View {
        switch state {
        case .loading:
            ProgressView("Carregando catálogo…").frame(maxWidth: .infinity).padding(.vertical, 40)
        case .loaded:
            EmptyView()
        case .failed(let message):
            ContentUnavailableView("Catálogo indisponível", systemImage: "exclamationmark.triangle", description: Text(message))
        }
    }
}

#Preview { ContentView() }
