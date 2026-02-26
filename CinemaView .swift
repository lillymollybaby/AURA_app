import SwiftUI
import Combine

// MARK: - Storage
class CinemaStorage: ObservableObject {
    static let shared = CinemaStorage()
    @Published var letterboxdUsername: String = UserDefaults.standard.string(forKey: "letterboxd_username") ?? ""
    @Published var kinopoiskConnected: Bool = UserDefaults.standard.bool(forKey: "kinopoisk_connected")
    @Published var imdbConnected: Bool = UserDefaults.standard.bool(forKey: "imdb_connected")
    var hasAnyPlatform: Bool { !letterboxdUsername.isEmpty || kinopoiskConnected || imdbConnected }
    func connectLetterboxd(_ username: String) {
        letterboxdUsername = username
        UserDefaults.standard.set(username, forKey: "letterboxd_username")
    }
    func disconnect() {
        letterboxdUsername = ""; kinopoiskConnected = false; imdbConnected = false
        UserDefaults.standard.removeObject(forKey: "letterboxd_username")
        UserDefaults.standard.set(false, forKey: "kinopoisk_connected")
        UserDefaults.standard.set(false, forKey: "imdb_connected")
    }
}

// MARK: - View Model
@MainActor
class CinemaViewModel: ObservableObject {
    @Published var trending: [MovieResponse] = []
    @Published var myMovies: [MovieResponse] = []
    @Published var searchResults: [MovieResponse] = []
    @Published var isLoadingTrending = false
    @Published var isSearching = false

    var watched: [MovieResponse] { myMovies.filter { $0.watched == true } }
    var watchlist: [MovieResponse] { myMovies.filter { $0.watched == false } }

    // Deduplicated trending by tmdb_id
    var uniqueTrending: [MovieResponse] {
        var seen = Set<Int>()
        return trending.filter { movie in
            let id = movie.tmdb_id ?? movie.id ?? 0
            guard id != 0 else { return false }
            return seen.insert(id).inserted
        }
    }

    func loadAll() async {
        isLoadingTrending = true
        async let t = NetworkManager.shared.getTrending()
        async let m = NetworkManager.shared.getMyMovies()
        trending = (try? await t) ?? []
        myMovies = (try? await m) ?? []
        isLoadingTrending = false
    }

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        searchResults = (try? await NetworkManager.shared.searchMovies(query: query)) ?? []
        isSearching = false
    }

    func markWatched(tmdbId: Int) async {
        let _ = try? await NetworkManager.shared.markWatched(tmdbId: tmdbId)
        // Update local state immediately
        if let idx = myMovies.firstIndex(where: { $0.tmdb_id == tmdbId || $0.id == tmdbId }) {
            let old = myMovies[idx]
            myMovies[idx] = MovieResponse(id: old.id, tmdb_id: old.tmdb_id, title: old.title,
                                          year: old.year, rating: old.rating, poster_url: old.poster_url,
                                          watched: true, review: old.review)
        } else {
            // Reload to get the new movie in list
            myMovies = (try? await NetworkManager.shared.getMyMovies()) ?? myMovies
        }
    }

    func addToWatchlist(tmdbId: Int) async {
        let _ = try? await NetworkManager.shared.addToWatchlist(tmdbId: tmdbId)
        myMovies = (try? await NetworkManager.shared.getMyMovies()) ?? myMovies
    }
}

// MARK: - Main View
struct CinemaView: View {
    @StateObject private var vm = CinemaViewModel()
    @State private var selectedTab = 0
    @State private var searchQuery = ""
    @State private var isSearchFocused = false
    @FocusState private var searchFieldFocused: Bool

    var showingSearch: Bool { isSearchFocused || !searchQuery.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Header (hides on search)
                if !showingSearch {
                    Picker("", selection: $selectedTab) {
                        Text("Trending").tag(0)
                        Text("My List").tag(1)
                        Text("Watchlist").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: Search bar
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Поиск фильмов", text: $searchQuery)
                            .focused($searchFieldFocused)
                            .onSubmit { Task { await vm.search(query: searchQuery) } }
                            .submitLabel(.search)
                            .onChange(of: searchFieldFocused) { focused in
                                withAnimation(.spring(response: 0.3)) {
                                    isSearchFocused = focused
                                }
                            }
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                vm.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if showingSearch {
                        Button("Отмена") {
                            withAnimation(.spring(response: 0.3)) {
                                searchQuery = ""
                                vm.searchResults = []
                                isSearchFocused = false
                                searchFieldFocused = false
                            }
                        }
                        .foregroundStyle(.blue)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.3), value: showingSearch)

                Divider()

                // MARK: Content
                if showingSearch {
                    SearchResultsView(vm: vm, searchQuery: searchQuery)
                        .transition(.opacity)
                } else {
                    TabView(selection: $selectedTab) {
                        TrendingTabView(vm: vm).tag(0)
                        MyListTabView(vm: vm).tag(1)
                        WatchlistTabView(vm: vm).tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.3), value: selectedTab)
                    .transition(.opacity)
                }
            }
            .navigationTitle("Cinema")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.loadAll() }
            .refreshable { await vm.loadAll() }
        }
        .animation(.spring(response: 0.3), value: showingSearch)
    }
}

// MARK: - Search Results
struct SearchResultsView: View {
    @ObservedObject var vm: CinemaViewModel
    let searchQuery: String

    var body: some View {
        Group {
            if vm.isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Ищем «\(searchQuery)»...").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.searchResults.isEmpty && !searchQuery.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundStyle(.tertiary)
                    Text("Введи название фильма").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("\(vm.searchResults.count) результатов") {
                        ForEach(vm.searchResults) { movie in
                            NavigationLink(destination: MovieDetailView(
                                tmdbId: movie.stableId,
                                title: movie.title,
                                isWatched: movie.watched == true,
                                vm: vm
                            )) {
                                MovieListRow(movie: movie)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Trending Tab
struct TrendingTabView: View {
    @ObservedObject var vm: CinemaViewModel

    var heroMovie: MovieResponse? { vm.uniqueTrending.first }
    var horizontalMovies: [MovieResponse] { Array(vm.uniqueTrending.dropFirst().prefix(5)) }
    var listMovies: [MovieResponse] { Array(vm.uniqueTrending.dropFirst(6)) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if vm.isLoadingTrending && vm.uniqueTrending.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Загружаем тренды...").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    // Hero
                    if let hero = heroMovie {
                        TrendingHeroCard(movie: hero, vm: vm).padding(.horizontal)
                    }

                    // Horizontal scroll
                    if !horizontalMovies.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Популярное сейчас").font(.headline).padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(horizontalMovies) { movie in
                                        NavigationLink(destination: MovieDetailView(
                                            tmdbId: movie.stableId, title: movie.title,
                                            isWatched: movie.watched == true, vm: vm
                                        )) {
                                            TrendingPosterCard(movie: movie)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Numbered list
                    if !listMovies.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Все в тренде").font(.headline).padding(.horizontal)
                            VStack(spacing: 0) {
                                ForEach(Array(listMovies.enumerated()), id: \.element.stableId) { i, movie in
                                    NavigationLink(destination: MovieDetailView(
                                        tmdbId: movie.stableId, title: movie.title,
                                        isWatched: movie.watched == true, vm: vm
                                    )) {
                                        HStack(spacing: 14) {
                                            Text("\(i + 7)")
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundStyle(.quaternary).frame(width: 26)
                                            if let url = movie.poster_url, let imageUrl = URL(string: url) {
                                                AsyncImage(url: imageUrl) { img in img.resizable().aspectRatio(contentMode: .fill) }
                                                    placeholder: { Color(.systemFill) }
                                                    .frame(width: 44, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(movie.title).font(.subheadline).fontWeight(.medium).lineLimit(2)
                                                HStack(spacing: 6) {
                                                    if let year = movie.year { Text(year).font(.caption).foregroundStyle(.secondary) }
                                                    if let rating = movie.rating {
                                                        HStack(spacing: 2) {
                                                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                                                            Text(String(format: "%.1f", rating)).font(.caption).foregroundStyle(.secondary)
                                                        }
                                                    }
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal).padding(.vertical, 10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    if i < listMovies.count - 1 { Divider().padding(.leading, 84) }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(16).padding(.horizontal)
                        }
                    }
                }
                Spacer(minLength: 30)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - My List Tab
struct MyListTabView: View {
    @ObservedObject var vm: CinemaViewModel

    var body: some View {
        List {
            if vm.watched.isEmpty {
                Section {
                    ContentUnavailableView("Нет просмотренных", systemImage: "film.stack",
                        description: Text("Найди фильм и отметь как просмотренный"))
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("Просмотрено (\(vm.watched.count))") {
                    ForEach(vm.watched) { movie in
                        NavigationLink(destination: MovieDetailView(
                            tmdbId: movie.stableId, title: movie.title, isWatched: true, vm: vm
                        )) { MovieListRow(movie: movie) }
                    }
                }
                if let random = vm.watched.randomElement() {
                    Section("Практика") {
                        NavigationLink(destination: MovieQuizView(movie: random)) {
                            Label("Квиз по «\(random.title)»", systemImage: "questionmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Watchlist Tab
struct WatchlistTabView: View {
    @ObservedObject var vm: CinemaViewModel

    var body: some View {
        List {
            if vm.watchlist.isEmpty {
                Section {
                    ContentUnavailableView("Watchlist пуст", systemImage: "bookmark",
                        description: Text("Добавляй фильмы которые хочешь посмотреть"))
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("Хочу посмотреть (\(vm.watchlist.count))") {
                    ForEach(vm.watchlist) { movie in
                        NavigationLink(destination: MovieDetailView(
                            tmdbId: movie.stableId, title: movie.title, isWatched: false, vm: vm
                        )) { MovieListRow(movie: movie) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Hero Card
struct TrendingHeroCard: View {
    let movie: MovieResponse
    let vm: CinemaViewModel
    var body: some View {
        NavigationLink(destination: MovieDetailView(
            tmdbId: movie.stableId, title: movie.title, isWatched: movie.watched == true, vm: vm
        )) {
            ZStack(alignment: .bottomLeading) {
                if let url = movie.poster_url, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { img in img.resizable().aspectRatio(contentMode: .fill) }
                        placeholder: { Rectangle().fill(Color(.systemGray4)) }
                        .frame(maxWidth: .infinity).frame(height: 360).clipped()
                }
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Label("#1 в тренде", systemImage: "flame.fill")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2)).cornerRadius(6)
                    Text(movie.title).font(.title2).bold().foregroundStyle(.white).lineLimit(2)
                    HStack(spacing: 10) {
                        if let year = movie.year { Text(year).font(.subheadline).foregroundStyle(.white.opacity(0.7)) }
                        if let rating = movie.rating {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating)).font(.subheadline).foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding()
            }
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Poster Card
struct TrendingPosterCard: View {
    let movie: MovieResponse
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let url = movie.poster_url, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { img in img.resizable().aspectRatio(contentMode: .fill) }
                        placeholder: { Rectangle().fill(Color(.systemGray4)).overlay(Image(systemName: "film").foregroundStyle(.secondary).font(.title)) }
                        .frame(width: 120, height: 175).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if let rating = movie.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating)).font(.caption2).bold()
                    }
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.ultraThinMaterial).cornerRadius(6).padding(6)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
            Text(movie.title).font(.caption).fontWeight(.medium).lineLimit(2).frame(width: 120, alignment: .leading)
            if let year = movie.year { Text(year).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}

// MARK: - Movie List Row
struct MovieListRow: View {
    let movie: MovieResponse
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = movie.poster_url, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { img in img.resizable().aspectRatio(contentMode: .fill) }
                        placeholder: { Color(.systemFill) }
                } else {
                    Color(.systemFill).overlay(Image(systemName: "film").foregroundStyle(.secondary))
                }
            }
            .frame(width: 44, height: 64).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title).font(.subheadline).fontWeight(.medium).lineLimit(2)
                HStack(spacing: 8) {
                    if let year = movie.year { Text(year).font(.caption).foregroundStyle(.secondary) }
                    if let rating = movie.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if movie.watched == true {
                    Label("Просмотрено", systemImage: "checkmark.circle.fill").font(.caption2).foregroundStyle(.green)
                } else if movie.watched == false {
                    Label("Watchlist", systemImage: "bookmark.fill").font(.caption2).foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
