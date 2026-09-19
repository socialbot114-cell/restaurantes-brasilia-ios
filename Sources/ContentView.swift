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
                .tabItem { Label("Favoritos", systemImage: "heart") }
        }
        .tint(Color(red: 0.04, green: 0.23, blue: 0.24))
    }
}

private struct HomeView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sabores da capital")
                            .font(.largeTitle.bold())
                        Text("Descubra lugares para comer em Brasília.")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    SearchField(text: $catalog.query)
                    CatalogStatusView(state: catalog.loadState)
                    SectionTitle(title: "Em destaque", count: catalog.filtered.count)
                    LazyVStack(spacing: 12) {
                        ForEach(catalog.filtered.prefix(12)) { restaurant in
                            NavigationLink {
                                RestaurantDetailView(restaurant: restaurant, favorites: favorites)
                            } label: {
                                RestaurantCard(restaurant: restaurant, isFavorite: favorites.contains(restaurant.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .safeAreaPadding(.bottom, 96)
            }
            .navigationTitle("Restaurantes Brasília")
        }
    }
}

private struct ExploreView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        NavigationStack {
            List {
                Section("Buscar") { SearchField(text: $catalog.query) }
                if catalog.loadState != .loaded {
                    CatalogStatusView(state: catalog.loadState)
                }
                Section("Região") {
                    Picker("Região", selection: $catalog.neighborhood) {
                        ForEach(catalog.neighborhoods, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Categoria") {
                    Picker("Categoria", selection: $catalog.category) {
                        ForEach(catalog.categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Resultados") {
                    ForEach(catalog.filtered) { restaurant in
                        NavigationLink {
                            RestaurantDetailView(restaurant: restaurant, favorites: favorites)
                        } label: {
                            RestaurantCard(restaurant: restaurant, isFavorite: favorites.contains(restaurant.id))
                        }
                    }
                }
            }
            .navigationTitle("Explorar")
            .safeAreaPadding(.bottom, 96)
            .toolbar { if catalog.query.isEmpty == false || catalog.neighborhood != "Todos" || catalog.category != "Todos" { Button("Limpar") { catalog.query = ""; catalog.neighborhood = "Todos"; catalog.category = "Todos" } } }
        }
    }
}

private struct FavoritesView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore

    var body: some View {
        NavigationStack {
            List {
                let saved = catalog.restaurants.filter { favorites.contains($0.id) }
                if saved.isEmpty {
                    ContentUnavailableView("Nenhum favorito", systemImage: "heart", description: Text("Toque no coração de um restaurante para encontrá-lo aqui."))
                } else {
                    ForEach(saved) { restaurant in
                        NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites) } label: {
                            RestaurantCard(restaurant: restaurant, isFavorite: true)
                        }
                    }
                }
            }
            .navigationTitle("Favoritos")
        }
    }
}

private struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @ObservedObject var favorites: FavoritesStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [Color(red: 0.04, green: 0.23, blue: 0.24), .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 180)
                    .overlay(Text(restaurant.displayCategory).font(.title2.bold()).foregroundStyle(.white).padding(), alignment: .bottomLeading)
                    .accessibilityLabel("Categoria: \(restaurant.displayCategory)")
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(restaurant.name).font(.title.bold())
                        Text("\(restaurant.displayNeighborhood) • \(restaurant.displayCategory)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { favorites.toggle(restaurant.id) } label: {
                        Image(systemName: favorites.contains(restaurant.id) ? "heart.fill" : "heart")
                    }
                    .accessibilityLabel(favorites.contains(restaurant.id) ? "Remover dos favoritos" : "Adicionar aos favoritos")
                }
                if restaurant.rating != nil || restaurant.reviewCount != nil {
                    HStack(spacing: 14) {
                        if let rating = restaurant.rating { Label(String(format: "%.1f", rating), systemImage: "star.fill").foregroundStyle(.orange) }
                        if let reviewCount = restaurant.reviewCount { Text("\(reviewCount) avaliações").foregroundStyle(.secondary) }
                    }
                }
                if let address = restaurant.address, !address.isEmpty { Label(address, systemImage: "mappin.and.ellipse") }
                if let verified = restaurant.lastVerified.nilIfEmpty { Text("Verificado em \(verified)").font(.footnote).foregroundStyle(.secondary) }
                VStack(spacing: 10) {
                    if let phone = restaurant.phone, let url = URL(string: "tel:\(phone.filter { $0.isNumber })") { ActionButton(title: "Ligar", systemImage: "phone", url: url, openURL: openURL) }
                    if let url = restaurant.normalizedWebsiteURL { ActionButton(title: "Abrir site", systemImage: "safari", url: url, openURL: openURL) }
                    let query = restaurant.address ?? "\(restaurant.name), Brasília DF"
                    if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Brasilia")") { ActionButton(title: "Como chegar", systemImage: "map", url: url, openURL: openURL) }
                }
            }
            .padding()
        }
        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RestaurantCard: View {
    let restaurant: Restaurant
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14).fill(Color.teal.opacity(0.18)).frame(width: 64, height: 64).overlay(Image(systemName: "fork.knife").foregroundStyle(.teal))
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name).font(.headline).foregroundStyle(.primary)
                Text(restaurant.displayCategory).font(.subheadline).foregroundStyle(.secondary)
                Text(restaurant.displayNeighborhood).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isFavorite { Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityHidden(true) }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.quaternary))
    }
}

private struct SearchField: View {
    @Binding var text: String
    var body: some View { HStack { Image(systemName: "magnifyingglass"); TextField("Buscar restaurante, categoria ou região", text: $text).textInputAutocapitalization(.never) }.padding(12).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14)) }
}

private struct CatalogStatusView: View {
    let state: CatalogLoadState

    var body: some View {
        switch state {
        case .loading:
            ProgressView("Carregando catálogo…")
        case .loaded:
            EmptyView()
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
        }
    }
}

private struct SectionTitle: View { let title: String; let count: Int; var body: some View { HStack { Text(title).font(.title2.bold()); Spacer(); Text("\(count)").foregroundStyle(.secondary) } } }

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let url: URL
    let openURL: OpenURLAction
    var body: some View { Button { openURL(url) } label: { Label(title, systemImage: systemImage).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent) }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

#Preview { ContentView() }
