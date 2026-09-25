import SwiftUI
import MapKit
import UIKit

struct ContentView: View {
    @StateObject private var catalog = RestaurantCatalog()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var dining = DiningExperienceStore()

    var body: some View {
        TabView {
            HomeView(catalog: catalog, favorites: favorites, dining: dining)
                .tabItem { Label("Início", systemImage: "house") }
            ExploreView(catalog: catalog, favorites: favorites, dining: dining)
                .tabItem { Label("Explorar", systemImage: "magnifyingglass") }
            DiningRoutesView(catalog: catalog, favorites: favorites, dining: dining)
                .tabItem { Label("Roteiros", systemImage: "map") }
            FavoritesView(catalog: catalog, favorites: favorites, dining: dining)
                .tabItem { Label("Salvos", systemImage: "heart") }
        }
        .tint(Theme.forest)
    }
}

// MARK: - Home

private struct HomeView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var dining: DiningExperienceStore
    @State private var query = ""
    @State private var selectedCategory: String?

    private struct Intent: Identifiable {
        let label: String
        let category: String
        var id: String { category }
    }

    private let intents: [Intent] = [
        Intent(label: "Café", category: "Cafeteria"),
        Intent(label: "Pizza", category: "Pizzaria"),
        Intent(label: "Hambúrguer", category: "Hamburgueria"),
        Intent(label: "Japonesa", category: "Japonesa"),
        Intent(label: "Brasileira", category: "Brasileira"),
        Intent(label: "Doces", category: "Doces"),
        Intent(label: "Saudável", category: "Saudável"),
        Intent(label: "Italiana", category: "Italiana")
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

                    if case .failed(let message) = catalog.loadState {
                        ContentUnavailableView("Catálogo indisponível", systemImage: "exclamationmark.triangle", description: Text(message))
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
                    ForEach(intents) { intent in
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

    private func intentChip(_ intent: Intent) -> some View {
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
                    ForEach(items) { restaurant in
                        NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites, dining: dining) } label: {
                            HeroCard(restaurant: restaurant)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("hero-\(restaurant.id)")
                    }
                }
            }
        }
    }

    private var cuisineGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explorar por cozinha").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(catalog.categoryRanking.prefix(8)) { item in
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
            NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites, dining: dining) } label: {
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
    @ObservedObject var dining: DiningExperienceStore
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

                    if case .failed(let message) = catalog.loadState {
                        ContentUnavailableView("Catálogo indisponível", systemImage: "exclamationmark.triangle", description: Text(message))
                    } else if results.isEmpty {
                        ContentUnavailableView("Nenhum resultado", systemImage: "magnifyingglass", description: Text("Ajuste a busca ou limpe os filtros."))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(results) { restaurant in
                                HStack(spacing: 10) {
                                    NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites, dining: dining) } label: {
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
    @ObservedObject var dining: DiningExperienceStore

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
                                    NavigationLink { RestaurantDetailView(restaurant: restaurant, favorites: favorites, dining: dining) } label: {
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

// MARK: - Dining routes

private struct DiningRoutesView: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var dining: DiningExperienceStore
    @State private var isCreatingRoute = false

    var body: some View {
        NavigationStack {
            Group {
                if dining.routes.isEmpty {
                    ContentUnavailableView {
                        Label("Monte seu primeiro roteiro", systemImage: "map")
                    } description: {
                        Text("Escolha lugares para conhecer, organize a ordem e guarde suas visitas.")
                    } actions: {
                        Button("Criar roteiro") { isCreatingRoute = true }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.forest)
                            .accessibilityIdentifier("create-route-empty")
                    }
                } else {
                    List {
                        ForEach(dining.routes) { route in
                            NavigationLink {
                                DiningRouteDetailView(routeID: route.id, catalog: catalog, favorites: favorites, dining: dining)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(route.name).font(.headline)
                                    Text("\(route.restaurantIDs.count) lugar\(route.restaurantIDs.count == 1 ? "" : "es") · criado em \(route.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                            .accessibilityIdentifier("route-\(route.id)")
                        }
                        .onDelete { offsets in
                            for offset in offsets.sorted(by: >) {
                                dining.deleteRoute(dining.routes[offset].id)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Theme.canvas)
            .navigationTitle("Roteiros")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreatingRoute = true } label: {
                        Label("Novo roteiro", systemImage: "plus")
                    }
                    .accessibilityIdentifier("create-route")
                }
            }
            .sheet(isPresented: $isCreatingRoute) {
                RouteNameSheet(title: "Novo roteiro", actionTitle: "Criar roteiro") { name in
                    dining.createRoute(name: name)
                }
            }
        }
    }
}

private struct DiningRouteDetailView: View {
    let routeID: String
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var dining: DiningExperienceStore
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingRestaurants = false
    @State private var isConfirmingDelete = false

    private var route: DiningRoute? { dining.route(withID: routeID) }

    var body: some View {
        Group {
            if let route {
                List {
                    Section {
                        if route.restaurantIDs.isEmpty {
                            ContentUnavailableView("Roteiro vazio", systemImage: "fork.knife", description: Text("Adicione restaurantes e organize a ordem da sua próxima saída."))
                        } else {
                            ForEach(route.restaurantIDs, id: \.self) { restaurantID in
                                if let restaurant = catalog.restaurants.first(where: { $0.id == restaurantID }) {
                                    HStack(spacing: 10) {
                                        NavigationLink {
                                            RestaurantDetailView(restaurant: restaurant, favorites: favorites, dining: dining)
                                        } label: {
                                            RestaurantCard(restaurant: restaurant, showFavorite: false)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("route-restaurant-\(restaurant.id)")
                                        Button(role: .destructive) {
                                            dining.removeRestaurant(restaurant.id, from: route.id)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(Theme.terracotta)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remover \(restaurant.name) do roteiro")
                                    }
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .onMove { dining.moveRestaurants(in: route.id, from: $0, to: $1) }
                        }
                    } header: {
                        Text("\(route.restaurantIDs.count) lugares · arraste para reordenar")
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(route.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { isAddingRestaurants = true } label: {
                            Label("Adicionar lugares", systemImage: "plus")
                        }
                        .accessibilityIdentifier("add-restaurants")
                        Menu {
                            Button("Excluir roteiro", role: .destructive) { isConfirmingDelete = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $isAddingRestaurants) {
                    AddRestaurantsSheet(catalog: catalog, dining: dining, routeID: route.id)
                }
                .confirmationDialog("Excluir este roteiro?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                    Button("Excluir roteiro", role: .destructive) {
                        dining.deleteRoute(route.id)
                        dismiss()
                    }
                }
            } else {
                ContentUnavailableView("Roteiro não encontrado", systemImage: "map")
            }
        }
    }
}

private struct AddRestaurantsSheet: View {
    @ObservedObject var catalog: RestaurantCatalog
    @ObservedObject var dining: DiningExperienceStore
    let routeID: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var restaurants: [Restaurant] {
        RestaurantCatalog.filter(catalog.restaurants, query: query)
    }

    var body: some View {
        NavigationStack {
            List(restaurants) { restaurant in
                Button {
                    dining.addRestaurant(restaurant.id, to: routeID)
                } label: {
                    HStack(spacing: 12) {
                        RestaurantArtwork(restaurant: restaurant, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(restaurant.name).font(.headline).foregroundStyle(.primary)
                            Text("\(restaurant.displayCategory) · \(restaurant.displayNeighborhood)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: dining.contains(restaurant.id, in: routeID) ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(dining.contains(restaurant.id, in: routeID) ? Theme.forest : Theme.terracotta)
                    }
                }
                .buttonStyle(.plain)
                .disabled(dining.contains(restaurant.id, in: routeID))
                .accessibilityIdentifier("add-restaurant-\(restaurant.id)")
            }
            .listStyle(.plain)
            .navigationTitle("Adicionar lugares")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Buscar restaurante")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Concluir") { dismiss() }
                        .accessibilityIdentifier("done-adding-restaurants")
                }
            }
        }
    }
}

private struct RouteNameSheet: View {
    let title: String
    let actionTitle: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome do roteiro") {
                    TextField("Ex.: Almoço de domingo", text: $name)
                        .accessibilityIdentifier("route-name-field")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-route")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Detail

private struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var dining: DiningExperienceStore
    @State private var isShowingVisitEditor = false
    @State private var isShowingRoutePicker = false
    @State private var isShowingMap = false
    @State private var copiedContact: String?

    private var style: CuisineStyle.Identity { CuisineStyle.identity(for: restaurant.displayCategory) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                if restaurant.photoAsset != nil {
                    Label("Foto: Tripadvisor", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                visitHistory

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
        .sheet(isPresented: $isShowingVisitEditor) {
            VisitEditorSheet(restaurant: restaurant, dining: dining)
        }
        .sheet(isPresented: $isShowingRoutePicker) {
            RoutePickerSheet(restaurant: restaurant, dining: dining)
        }
        .sheet(isPresented: $isShowingMap) {
            RestaurantMapSheet(restaurant: restaurant)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let photoAsset = restaurant.photoAsset {
                Image(photoAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [style.tint, Theme.forestDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 220)
                Image(systemName: style.symbol)
                    .font(.system(size: 84))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
            }
            Text(restaurant.displayCategory)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityLabel(restaurant.photoAsset == nil ? "Categoria \(restaurant.displayCategory)" : "Foto de \(restaurant.name)")
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
            Button { isShowingRoutePicker = true } label: {
                Label("Adicionar a um roteiro", systemImage: "map.badge.plus")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.forest)
            .accessibilityIdentifier("add-to-route")

            Button { isShowingVisitEditor = true } label: {
                Label("Registrar visita", systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(Theme.forest)
            .accessibilityIdentifier("record-visit")

            Button { isShowingMap = true } label: {
                Label("Ver mapa no app", systemImage: "map")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(Theme.forest)
            .accessibilityIdentifier("show-internal-map")

            if let phone = restaurant.phone, !phone.isEmpty {
                copyButton(value: phone, title: "Telefone: \(phone)", copiedTitle: "Telefone copiado", symbol: "phone")
            }
            if let address = restaurant.address, !address.isEmpty {
                copyButton(value: address, title: "Copiar endereço", copiedTitle: "Endereço copiado", symbol: "mappin")
            }
        }
    }

    private func copyButton(value: String, title: String, copiedTitle: String, symbol: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copiedContact = value
        } label: {
            Label(copiedContact == value ? copiedTitle : title, systemImage: symbol)
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(Theme.forest)
    }

    private var visitHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meu diário").font(.title3.bold())
                Spacer()
                Text("\(dining.visits(for: restaurant.id).count) visita\(dining.visits(for: restaurant.id).count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if dining.visits(for: restaurant.id).isEmpty {
                Text("Suas datas, notas e observações ficam salvas somente neste aparelho.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(dining.visits(for: restaurant.id)) { visit in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(visit.visitedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Label("\(visit.personalRating)/5", systemImage: "star.fill")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.ipe)
                            Button {
                                dining.deleteVisit(visit.id)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(Theme.terracotta)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Excluir anotação")
                        }
                        if !visit.note.isEmpty {
                            Text(visit.note).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                }
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

private struct RoutePickerSheet: View {
    let restaurant: Restaurant
    @ObservedObject var dining: DiningExperienceStore
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingRoute = false

    var body: some View {
        NavigationStack {
            Group {
                if dining.routes.isEmpty {
                    ContentUnavailableView {
                        Label("Crie um roteiro", systemImage: "map")
                    } description: {
                        Text("Você pode organizar os lugares que pretende conhecer.")
                    } actions: {
                        Button("Criar roteiro") { isCreatingRoute = true }
                            .buttonStyle(.borderedProminent).tint(Theme.forest)
                    }
                } else {
                    List(dining.routes) { route in
                        Button {
                            dining.addRestaurant(restaurant.id, to: route.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name).font(.headline)
                                    Text("\(route.restaurantIDs.count) lugares").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: dining.contains(restaurant.id, in: route.id) ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(Theme.forest)
                            }
                        }
                        .disabled(dining.contains(restaurant.id, in: route.id))
                        .accessibilityIdentifier("select-route-\(route.id)")
                    }
                }
            }
            .navigationTitle("Adicionar ao roteiro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isCreatingRoute = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Criar roteiro")
                }
            }
            .sheet(isPresented: $isCreatingRoute) {
                RouteNameSheet(title: "Novo roteiro", actionTitle: "Criar e adicionar") { name in
                    if let route = dining.createRoute(name: name) {
                        dining.addRestaurant(restaurant.id, to: route.id)
                    }
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct VisitEditorSheet: View {
    let restaurant: Restaurant
    @ObservedObject var dining: DiningExperienceStore
    @Environment(\.dismiss) private var dismiss
    @State private var visitedAt = Date()
    @State private var rating = 5
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Visita") {
                    DatePicker("Data", selection: $visitedAt, displayedComponents: .date)
                    Picker("Minha nota", selection: $rating) {
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value) \(value == 1 ? "estrela" : "estrelas")").tag(value)
                        }
                    }
                    .accessibilityIdentifier("visit-rating")
                }
                Section("Anotações pessoais") {
                    TextField("Como foi a experiência?", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                        .accessibilityIdentifier("visit-note")
                }
            }
            .navigationTitle("Registrar visita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        dining.recordVisit(restaurantID: restaurant.id, visitedAt: visitedAt, personalRating: rating, note: note)
                        dismiss()
                    }
                    .accessibilityIdentifier("save-visit")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RestaurantMapPin: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
}

private struct RestaurantMapSheet: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -15.7939, longitude: -47.8828),
            span: MKCoordinateSpan(latitudeDelta: 0.16, longitudeDelta: 0.16)
        )
    )
    @State private var pins: [RestaurantMapPin] = []
    @State private var mapMessage = "Buscando o local no mapa…"

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(pins) { pin in
                    Marker(pin.title, coordinate: pin.coordinate).tint(Theme.terracotta)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(restaurant.name).font(.headline)
                    if let address = restaurant.address, !address.isEmpty {
                        Text(address).font(.caption).foregroundStyle(.secondary)
                    }
                    if pins.isEmpty { Text(mapMessage).font(.caption).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
            }
            .navigationTitle("Mapa interno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Fechar") { dismiss() } }
            }
            .task { await searchForRestaurant() }
        }
        .presentationDetents([.large])
    }

    @MainActor
    private func searchForRestaurant() async {
        var request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [restaurant.name, restaurant.address, "Brasília DF"]
            .compactMap { $0 }
            .joined(separator: ", ")
        request.resultTypes = .pointOfInterest
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else {
            mapMessage = "Não encontramos um ponto exato. O mapa continua centralizado em Brasília."
            return
        }
        let coordinate = item.placemark.coordinate
        pins = [RestaurantMapPin(id: restaurant.id, title: item.name ?? restaurant.name, coordinate: coordinate)]
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1400, longitudinalMeters: 1400))
        mapMessage = "Local aproximado"
    }
}

// MARK: - Components

private struct RestaurantArtwork: View {
    let restaurant: Restaurant
    let size: CGFloat

    private var style: CuisineStyle.Identity { CuisineStyle.identity(for: restaurant.displayCategory) }

    var body: some View {
        Group {
            if let photoAsset = restaurant.photoAsset {
                Image(photoAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(style.tint.opacity(0.16))
                    Image(systemName: style.symbol).font(.system(size: size * 0.4)).foregroundStyle(style.tint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel(restaurant.photoAsset == nil ? restaurant.displayCategory : "Foto de \(restaurant.name)")
    }
}

private struct RestaurantCard: View {
    let restaurant: Restaurant
    var showFavorite: Bool = false

    private var style: CuisineStyle.Identity { CuisineStyle.identity(for: restaurant.displayCategory) }

    var body: some View {
        HStack(spacing: 14) {
            RestaurantArtwork(restaurant: restaurant, size: 60)
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
                if let photoAsset = restaurant.photoAsset {
                    Image(photoAsset).resizable().scaledToFill().frame(width: 180, height: 110).clipped()
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [style.tint, style.tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 110)
                    Image(systemName: style.symbol).font(.system(size: 40)).foregroundStyle(.white.opacity(0.95))
                }
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
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("restaurant-search-field")
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

#Preview { ContentView() }
