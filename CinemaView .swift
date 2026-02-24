import SwiftUI
import Combine
// MARK: - Cinema Models
struct LetterboxdProfile: Codable {
    let username: String
    let connected: Bool
}

// MARK: - Cinema Storage
class CinemaStorage: ObservableObject {
    static let shared = CinemaStorage()
    
    @Published var letterboxdUsername: String = UserDefaults.standard.string(forKey: "letterboxd_username") ?? ""
    @Published var kinopoiskConnected: Bool = UserDefaults.standard.bool(forKey: "kinopoisk_connected")
    @Published var imdbConnected: Bool = UserDefaults.standard.bool(forKey: "imdb_connected")
    
    var hasAnyPlatform: Bool {
        !letterboxdUsername.isEmpty || kinopoiskConnected || imdbConnected
    }
    
    func connectLetterboxd(_ username: String) {
        letterboxdUsername = username
        UserDefaults.standard.set(username, forKey: "letterboxd_username")
    }
    
    func disconnect() {
        letterboxdUsername = ""
        kinopoiskConnected = false
        imdbConnected = false
        UserDefaults.standard.removeObject(forKey: "letterboxd_username")
        UserDefaults.standard.set(false, forKey: "kinopoisk_connected")
        UserDefaults.standard.set(false, forKey: "imdb_connected")
    }
}

// MARK: - CINEMA VIEW
struct CinemaView: View {
    @StateObject private var storage = CinemaStorage.shared
    @State private var trending: [MovieResponse] = []
    @State private var myMovies: [MovieResponse] = []
    @State private var searchQuery = ""
    @State private var searchResults: [MovieResponse] = []
    @State private var showPlatformConnect = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: Platform Banner
                    if !storage.hasAnyPlatform {
                        ConnectPlatformBanner()
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .onTapGesture { showPlatformConnect = true }
                    } else {
                        ConnectedPlatformBar()
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }
                    
                    // MARK: Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Поиск фильмов...", text: $searchQuery)
                            .onSubmit { Task { await searchMovies() } }
                        if !searchQuery.isEmpty {
                            Button { searchQuery = ""; searchResults = [] } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)
                    .padding(.top, 14)
                    
                    // MARK: Tab Picker
                    HStack(spacing: 0) {
                        ForEach(["Trending", "My List", "Watchlist"], id: \.self) { tab in
                            let idx = ["Trending", "My List", "Watchlist"].firstIndex(of: tab)!
                            Button {
                                withAnimation(.spring(response: 0.3)) { selectedTab = idx }
                            } label: {
                                Text(tab)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == idx ? .bold : .regular)
                                    .foregroundColor(selectedTab == idx ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedTab == idx ?
                                        Color(.systemBackground) : Color.clear
                                    )
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.top, 14)
                    
                    // MARK: Search Results
                    if !searchResults.isEmpty {
                        MovieGridSection(title: "Результаты", icon: "magnifyingglass", movies: searchResults)
                            .padding(.top, 16)
                    }
                    
                    // MARK: Main Content
                    Group {
                        if selectedTab == 0 {
                            // Trending
                            if trending.isEmpty {
                                ProgressView("Загружаем...").padding(.top, 40)
                            } else {
                                MovieGridSection(title: "В тренде", icon: "flame.fill", movies: trending, iconColor: .orange)
                                    .padding(.top, 16)
                            }
                        } else if selectedTab == 1 {
                            // My List
                            if myMovies.filter { $0.watched == true }.isEmpty {
                                EmptyStateView(
                                    icon: "film.stack",
                                    title: "Нет просмотренных",
                                    subtitle: "Найди фильм и отметь как просмотренный"
                                ).padding(.top, 40)
                            } else {
                                MovieGridSection(
                                    title: "Просмотрено",
                                    icon: "checkmark.circle.fill",
                                    movies: myMovies.filter { $0.watched == true },
                                    iconColor: .green
                                ).padding(.top, 16)
                            }
                        } else {
                            // Watchlist
                            if myMovies.filter { $0.watched == false }.isEmpty {
                                EmptyStateView(
                                    icon: "bookmark",
                                    title: "Watchlist пуст",
                                    subtitle: "Добавляй фильмы которые хочешь посмотреть"
                                ).padding(.top, 40)
                            } else {
                                MovieGridSection(
                                    title: "Хочу посмотреть",
                                    icon: "bookmark.fill",
                                    movies: myMovies.filter { $0.watched == false },
                                    iconColor: .blue
                                ).padding(.top, 16)
                            }
                        }
                    }
                    
                    // MARK: Quiz Card
                    if !myMovies.isEmpty, let randomMovie = myMovies.filter({ $0.watched == true }).randomElement() {
                        NavigationLink(destination: MovieQuizView(movie: randomMovie)) {
                            QuizBannerCard(movie: randomMovie)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cinema")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPlatformConnect = true
                    } label: {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showPlatformConnect) {
            PlatformConnectSheet()
        }
        .task {
            async let t = NetworkManager.shared.getTrending()
            async let m = NetworkManager.shared.getMyMovies()
            trending = (try? await t) ?? []
            myMovies = (try? await m) ?? []
        }
    }
    
    func searchMovies() async {
        if let r = try? await NetworkManager.shared.searchMovies(query: searchQuery) {
            searchResults = r
        }
    }
}

// MARK: - Movie Grid Section
struct MovieGridSection: View {
    let title: String
    let icon: String
    let movies: [MovieResponse]
    var iconColor: Color = .secondary
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon).foregroundColor(iconColor)
                Text(title).font(.headline)
                Spacer()
                Text("\(movies.count)").font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(.systemGray6)).cornerRadius(8)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(movies, id: \.stableId) { movie in
                    NavigationLink(destination: MovieDetailView(movie: movie)) {
                        CompactMovieCard(movie: movie)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Compact Movie Card (3 column grid)
struct CompactMovieCard: View {
    let movie: MovieResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let posterUrl = movie.poster_url, let url = URL(string: posterUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(LinearGradient(
                            colors: [Color(red:0.1,green:0.1,blue:0.2), Color(red:0.2,green:0.1,blue:0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(Image(systemName: "film").foregroundColor(.white.opacity(0.3)).font(.title2))
                    }
                    .aspectRatio(2/3, contentMode: .fill)
                    .clipped()
                } else {
                    Rectangle().fill(LinearGradient(
                        colors: [Color(red:0.1,green:0.1,blue:0.2), Color(red:0.2,green:0.1,blue:0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .aspectRatio(2/3, contentMode: .fill)
                    .overlay(
                        Text(movie.title).font(.caption2).bold().foregroundColor(.white)
                            .multilineTextAlignment(.center).padding(6)
                    )
                }
                
                // Rating badge
                if let rating = movie.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 7)).foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating)).font(.system(size: 9)).bold().foregroundColor(.white)
                    }
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(5)
                }
                
                // Watched badge
                if movie.watched == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                        .padding(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            Text(movie.title)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let year = movie.year {
                Text(year).font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Connect Platform Banner
struct ConnectPlatformBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(red:0.2,green:0.5,blue:1.0), Color(red:0.5,green:0.2,blue:1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                Image(systemName: "link.badge.plus")
                    .foregroundColor(.white)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Подключи платформы")
                    .font(.subheadline).bold()
                Text("Letterboxd, Кинопоиск, IMDB")
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Connected Platform Bar
struct ConnectedPlatformBar: View {
    @StateObject private var storage = CinemaStorage.shared
    
    var body: some View {
        HStack(spacing: 10) {
            if !storage.letterboxdUsername.isEmpty {
                PlatformBadge(name: "LB", color: Color(red:0.0,green:0.7,blue:0.4), label: "@\(storage.letterboxdUsername)")
            }
            if storage.kinopoiskConnected {
                PlatformBadge(name: "КП", color: Color(red:1.0,green:0.6,blue:0.0), label: "Кинопоиск")
            }
            if storage.imdbConnected {
                PlatformBadge(name: "IMDb", color: Color(red:0.9,green:0.7,blue:0.0), label: "IMDB")
            }
            Spacer()
            Text("Синхронизировано").font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct PlatformBadge: View {
    let name: String
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Text(name).font(.caption2).bold().foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(color).cornerRadius(6)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Platform Connect Sheet
struct PlatformConnectSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storage = CinemaStorage.shared
    @State private var letterboxdInput = ""
    @State private var showingLetterboxdInput = false
    @State private var isLoading = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "film.stack.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Text("Подключи платформы")
                            .font(.title2).bold()
                        Text("Синхронизируй свои фильмы и получай персональные уроки")
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Platforms
                    VStack(spacing: 12) {
                        // Letterboxd
                        PlatformConnectCard(
                            logo: "🎬",
                            name: "Letterboxd",
                            description: "Импорт просмотренных фильмов и wishlist",
                            color: Color(red:0.0,green:0.7,blue:0.4),
                            isConnected: !storage.letterboxdUsername.isEmpty,
                            connectedLabel: storage.letterboxdUsername.isEmpty ? nil : "@\(storage.letterboxdUsername)"
                        ) {
                            withAnimation { showingLetterboxdInput.toggle() }
                        }
                        
                        if showingLetterboxdInput {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("letterboxd.com/")
                                        .foregroundColor(.secondary).font(.subheadline)
                                    TextField("username", text: $letterboxdInput)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                
                                Button {
                                    guard !letterboxdInput.isEmpty else { return }
                                    isLoading = true
                                    storage.connectLetterboxd(letterboxdInput)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        isLoading = false
                                        showingLetterboxdInput = false
                                        successMessage = "Letterboxd подключён!"
                                    }
                                } label: {
                                    HStack {
                                        if isLoading { ProgressView().tint(.white) }
                                        else { Text("Подключить").fontWeight(.semibold) }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red:0.0,green:0.7,blue:0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Kinopoisk
                        PlatformConnectCard(
                            logo: "🎥",
                            name: "Кинопоиск",
                            description: "Синхронизация оценок и списков",
                            color: Color(red:1.0,green:0.6,blue:0.0),
                            isConnected: storage.kinopoiskConnected,
                            connectedLabel: storage.kinopoiskConnected ? "Подключён" : nil
                        ) {
                            storage.kinopoiskConnected.toggle()
                            UserDefaults.standard.set(storage.kinopoiskConnected, forKey: "kinopoisk_connected")
                        }
                        
                        // IMDB
                        PlatformConnectCard(
                            logo: "⭐",
                            name: "IMDB",
                            description: "Импорт watchlist и рейтингов",
                            color: Color(red:0.9,green:0.7,blue:0.0),
                            isConnected: storage.imdbConnected,
                            connectedLabel: storage.imdbConnected ? "Подключён" : nil
                        ) {
                            storage.imdbConnected.toggle()
                            UserDefaults.standard.set(storage.imdbConnected, forKey: "imdb_connected")
                        }
                    }
                    .padding(.horizontal)
                    
                    // What you get
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Что ты получишь").font(.headline).padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            FeatureRow(icon: "bell.badge.fill", color: .blue, text: "Пуш когда залогируешь фильм — разбор слов, актёров, фактов")
                            FeatureRow(icon: "textformat.abc", color: .purple, text: "Слова из фильмов в твой словарь Languages")
                            FeatureRow(icon: "map.fill", color: .green, text: "Карта мест съёмки через Logistics")
                            FeatureRow(icon: "questionmark.circle.fill", color: .orange, text: "Квизы по цитатам из просмотренных фильмов")
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    if !successMessage.isEmpty {
                        Text("✅ \(successMessage)")
                            .font(.subheadline).foregroundColor(.green)
                            .padding()
                    }
                    
                    if storage.hasAnyPlatform {
                        Button(role: .destructive) {
                            storage.disconnect()
                        } label: {
                            Text("Отключить все платформы")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer(minLength: 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Платформы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct PlatformConnectCard: View {
    let logo: String
    let name: String
    let description: String
    let color: Color
    let isConnected: Bool
    let connectedLabel: String?
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Text(logo).font(.title2)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline).bold()
                Text(description).font(.caption).foregroundColor(.secondary)
                if let label = connectedLabel {
                    Text(label).font(.caption2).foregroundColor(color).bold()
                }
            }
            
            Spacer()
            
            Button(action: action) {
                Text(isConnected ? "✓" : "Подключить")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(isConnected ? .white : color)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(isConnected ? color : color.opacity(0.12))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isConnected ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(color).font(.subheadline).frame(width: 22)
            Text(text).font(.subheadline).foregroundColor(.secondary)
        }
    }
}

// MARK: - Quiz Banner Card
struct QuizBannerCard: View {
    let movie: MovieResponse
    
    var body: some View {
        HStack(spacing: 14) {
            if let posterUrl = movie.poster_url, let url = URL(string: posterUrl) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 54, height: 54)
                .cornerRadius(10)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("🎯 Квиз по словам").font(.caption).foregroundColor(.orange).bold()
                Text(movie.title).font(.subheadline).bold().lineLimit(1)
                Text("Проверь слова из этого фильма").font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary).font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1.5)
        )
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title).font(.headline).foregroundColor(.secondary)
            Text(subtitle).font(.subheadline).foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - MOVIE QUIZ VIEW
struct MovieQuizView: View {
    let movie: MovieResponse
    @State private var words: [MovieWord] = []
    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var score = 0
    @State private var finished = false
    @State private var isLoading = true
    @State private var userChoice: String? = nil
    @State private var options: [String] = []
    
    let allTranslations = [
        "преследуемый/проклятый", "зловещий", "предательство", "искупление",
        "одержимость", "месть", "заговор", "обман", "стойкость", "амбиции",
        "коррупция", "изоляция", "манипуляция", "жертва", "загадочный",
        "безжалостный", "отчаянный", "хитрый", "неумолимый", "неизбежный"
    ]
    
    var currentWord: MovieWord? { words.isEmpty ? nil : words[currentIndex] }
    var progress: Double { words.isEmpty ? 0 : Double(currentIndex) / Double(words.count) }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем слова...").font(.subheadline).foregroundColor(.secondary)
                }
            } else if finished {
                QuizResultView(score: score, total: words.count, movie: movie)
            } else if let word = currentWord {
                VStack(spacing: 0) {
                    // Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Вопрос \(currentIndex + 1) из \(words.count)")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text("⭐ \(score)").font(.subheadline).bold()
                        }
                        ProgressView(value: progress)
                            .tint(.orange)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Word card
                            VStack(spacing: 12) {
                                Text(word.word)
                                    .font(.system(size: 36, weight: .bold))
                                    .multilineTextAlignment(.center)
                                
                                if let example = word.example {
                                    Text("💬 \(example)")
                                        .font(.subheadline).italic()
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                if let context = word.context, showAnswer {
                                    Text("📍 \(context)")
                                        .font(.caption).foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                        .transition(.opacity)
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .padding(.horizontal)
                            
                            // Question
                            Text("Что означает это слово?")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            // Options
                            VStack(spacing: 10) {
                                ForEach(options, id: \.self) { option in
                                    QuizOptionButton(
                                        text: option,
                                        state: optionState(option),
                                        isDisabled: showAnswer
                                    ) {
                                        guard !showAnswer else { return }
                                        userChoice = option
                                        withAnimation { showAnswer = true }
                                        if option == word.translation {
                                            score += 1
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Next button
                            if showAnswer {
                                Button {
                                    withAnimation {
                                        if currentIndex + 1 >= words.count {
                                            finished = true
                                        } else {
                                            currentIndex += 1
                                            showAnswer = false
                                            userChoice = nil
                                            generateOptions()
                                        }
                                    }
                                } label: {
                                    Text(currentIndex + 1 >= words.count ? "Завершить" : "Следующий →")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
        }
        .navigationTitle("Квиз: \(movie.title)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadWords() }
    }
    
    func optionState(_ option: String) -> QuizOptionState {
        guard showAnswer else { return .normal }
        if option == currentWord?.translation { return .correct }
        if option == userChoice { return .wrong }
        return .normal
    }
    
    func loadWords() {
        Task {
            let result = try? await NetworkManager.shared.getMovieWords(tmdbId: movie.stableId)
            words = result?.words ?? []
            isLoading = false
            generateOptions()
        }
    }
    
    func generateOptions() {
        guard let word = currentWord else { return }
        var opts = [word.translation]
        let distractors = allTranslations.filter { $0 != word.translation }.shuffled().prefix(3)
        opts.append(contentsOf: distractors)
        options = opts.shuffled()
    }
}

enum QuizOptionState { case normal, correct, wrong }

struct QuizOptionButton: View {
    let text: String
    let state: QuizOptionState
    let isDisabled: Bool
    let action: () -> Void
    
    var bgColor: Color {
        switch state {
        case .normal: return Color(.systemBackground)
        case .correct: return Color.green.opacity(0.15)
        case .wrong: return Color.red.opacity(0.15)
        }
    }
    
    var borderColor: Color {
        switch state {
        case .normal: return Color.clear
        case .correct: return Color.green
        case .wrong: return Color.red
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text).font(.subheadline).fontWeight(.medium)
                Spacer()
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                else if state == .wrong { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
            }
            .padding()
            .background(bgColor)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1.5))
        }
        .foregroundColor(.primary)
        .disabled(isDisabled)
        .animation(.spring(response: 0.3), value: state)
    }
}

struct QuizResultView: View {
    let score: Int
    let total: Int
    let movie: MovieResponse
    @Environment(\.dismiss) var dismiss
    
    var percentage: Double { total > 0 ? Double(score) / Double(total) : 0 }
    var emoji: String {
        if percentage >= 0.8 { return "🏆" }
        if percentage >= 0.6 { return "👍" }
        return "📚"
    }
    var message: String {
        if percentage >= 0.8 { return "Отлично! Ты хорошо знаешь этот фильм" }
        if percentage >= 0.6 { return "Неплохо! Продолжай изучать" }
        return "Есть куда расти! Пересмотри слова"
    }
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Text(emoji).font(.system(size: 70))
            
            VStack(spacing: 8) {
                Text("\(score)/\(total)").font(.system(size: 52, weight: .bold))
                Text(message).font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            
            // Score ring
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 12).frame(width: 100, height: 100)
                Circle().trim(from: 0, to: percentage)
                    .stroke(percentage >= 0.6 ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percentage * 100))%").font(.headline).bold()
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Готово")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - MOVIE DETAIL VIEW
struct MovieDetailView: View {
    let movie: MovieResponse
    @State private var details: MovieDetails? = nil
    @State private var words: [MovieWord] = []
    @State private var critique: String = ""
    @State private var isLoadingDetails = true
    @State private var isLoadingWords = false
    @State private var isLoadingCritique = false
    @State private var showWords = false
    @State private var showCritique = false
    @State private var showLocations = false
    @State private var addedToWatchlist = false
    @State private var markedWatched = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: Backdrop
                ZStack(alignment: .bottom) {
                    if let backdropURL = details?.backdrop_url, let url = URL(string: backdropURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(LinearGradient(
                                    colors: [Color(red:0.05,green:0.05,blue:0.2), Color(red:0.1,green:0.05,blue:0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                            }
                        }
                        .frame(height: 240)
                        .clipped()
                    } else {
                        Rectangle().fill(LinearGradient(
                            colors: [Color(red:0.05,green:0.05,blue:0.2), Color(red:0.1,green:0.05,blue:0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, Color(.systemGroupedBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: details?.backdrop_url != nil ? 240 : 200)
                }
                
                // MARK: Постер + инфо
                HStack(alignment: .bottom, spacing: 16) {
                    if let posterURL = movie.poster_url, let url = URL(string: posterURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                            default: Rectangle().fill(Color.gray.opacity(0.3))
                                    .overlay(Image(systemName: "film").foregroundColor(.gray).font(.title))
                            }
                        }
                        .frame(width: 110, height: 165)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .offset(y: -30)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(movie.title).font(.title3).bold().lineLimit(2)
                        
                        if let orig = details?.original_title, orig != movie.title {
                            Text(orig).font(.caption).foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            if let year = movie.year { Text(year).font(.caption).foregroundColor(.secondary) }
                            if let runtime = details?.runtime {
                                Text("·").foregroundColor(.secondary)
                                Text("\(runtime) мин").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        
                        if let rating = movie.rating {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption)
                                Text(String(format: "%.1f", rating)).bold().font(.subheadline)
                                if let count = details?.vote_count {
                                    Text("(\(count))").foregroundColor(.secondary).font(.caption)
                                }
                            }
                        }
                        
                        if let genres = details?.genres, !genres.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(genres.prefix(3), id: \.self) { genre in
                                        Text(genre).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .padding(.top, -10)
                
                VStack(alignment: .leading, spacing: 18) {
                    
                    // MARK: Action Buttons
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                let _ = try? await NetworkManager.shared.markWatched(tmdbId: movie.stableId)
                                withAnimation { markedWatched = true }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: markedWatched ? "checkmark.circle.fill" : "eye.fill")
                                Text(markedWatched ? "Просмотрено" : "Просмотрел")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(markedWatched ? Color.green : Color.blue)
                            .foregroundColor(.white).cornerRadius(14)
                        }
                        
                        Button {
                            Task {
                                let _ = try? await NetworkManager.shared.addToWatchlist(tmdbId: movie.stableId)
                                withAnimation { addedToWatchlist = true }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: addedToWatchlist ? "bookmark.fill" : "bookmark")
                                Text(addedToWatchlist ? "В списке" : "Watchlist")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(addedToWatchlist ? Color.green : Color(.systemGray5))
                            .foregroundColor(addedToWatchlist ? .white : .primary).cornerRadius(14)
                        }
                        
                        // Quiz button
                        NavigationLink(destination: MovieQuizView(movie: movie)) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title2).foregroundColor(.orange)
                                .frame(width: 48, height: 48)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(14)
                        }
                    }
                    
                    // MARK: Tagline
                    if let tagline = details?.tagline, !tagline.isEmpty {
                        Text("«\(tagline)»").italic().foregroundColor(.secondary)
                            .font(.subheadline).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    
                    // MARK: О фильме
                    if let overview = details?.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("О фильме").font(.headline)
                            Text(overview).font(.body).foregroundColor(.secondary).lineSpacing(4)
                        }
                    }
                    
                    // MARK: Режиссёр + Сценарист
                    if let directors = details?.directors, !directors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Режиссёр").font(.headline)
                            Text(directors.joined(separator: ", ")).foregroundColor(.secondary)
                        }
                    }
                    if let writers = details?.writers, !writers.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Сценарист").font(.headline)
                            Text(writers.joined(separator: ", ")).foregroundColor(.secondary)
                        }
                    }
                    
                    // MARK: Актёры
                    if let cast = details?.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Актёры").font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(cast, id: \.name) { actor in
                                        VStack(spacing: 6) {
                                            Group {
                                                if let profileURL = actor.profile_url, let url = URL(string: profileURL) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                                                        default: Circle().fill(Color.gray.opacity(0.3)).overlay(Image(systemName: "person").foregroundColor(.gray))
                                                        }
                                                    }
                                                } else {
                                                    Circle().fill(Color.gray.opacity(0.3)).overlay(Image(systemName: "person").foregroundColor(.gray))
                                                }
                                            }
                                            .frame(width: 64, height: 64).clipShape(Circle()).shadow(radius: 3)
                                            
                                            Text(actor.name).font(.caption2).bold()
                                                .multilineTextAlignment(.center).lineLimit(2).frame(width: 72)
                                            Text(actor.character).font(.caption2).foregroundColor(.secondary)
                                                .multilineTextAlignment(.center).lineLimit(2).frame(width: 72)
                                        }
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // MARK: Карта съёмок
                    Button {
                        withAnimation { showLocations.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "map.fill").foregroundColor(.green)
                            Text("Карта съёмок").fontWeight(.medium)
                            Spacer()
                            Image(systemName: showLocations ? "chevron.up" : "chevron.down").foregroundColor(.secondary)
                        }
                        .padding().background(Color.green.opacity(0.08)).cornerRadius(14)
                    }
                    .foregroundColor(.primary)
                    
                    if showLocations {
                        FilmingLocationsView(movieTitle: movie.title, details: details)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: AI Рецензия
                    VStack(spacing: 10) {
                        Button {
                            withAnimation { showCritique.toggle() }
                            if critique.isEmpty && !isLoadingCritique {
                                isLoadingCritique = true
                                Task {
                                    critique = (try? await NetworkManager.shared.getFilmCritique(tmdbId: movie.stableId)) ?? "Не удалось загрузить рецензию"
                                    isLoadingCritique = false
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "theatermasks.fill").foregroundColor(.purple)
                                Text("AI Рецензия").fontWeight(.medium)
                                Spacer()
                                if isLoadingCritique { ProgressView().scaleEffect(0.8) }
                                else { Image(systemName: showCritique ? "chevron.up" : "chevron.down").foregroundColor(.secondary) }
                            }
                            .padding().background(Color.purple.opacity(0.08)).cornerRadius(14)
                        }
                        .foregroundColor(.primary)
                        
                        if showCritique && !critique.isEmpty {
                            Text(critique).font(.body).lineSpacing(4).padding()
                                .background(Color.purple.opacity(0.05)).cornerRadius(12)
                        }
                    }
                    
                    // MARK: Слова из фильма
                    VStack(spacing: 10) {
                        Button {
                            withAnimation { showWords.toggle() }
                            if words.isEmpty && !isLoadingWords {
                                isLoadingWords = true
                                Task {
                                    let result = try? await NetworkManager.shared.getMovieWords(tmdbId: movie.stableId)
                                    words = result?.words ?? []
                                    isLoadingWords = false
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "textformat.abc").foregroundColor(.blue)
                                Text("Слова из фильма").fontWeight(.medium)
                                Spacer()
                                if isLoadingWords { ProgressView().scaleEffect(0.8) }
                                else { Image(systemName: showWords ? "chevron.up" : "chevron.down").foregroundColor(.secondary) }
                            }
                            .padding().background(Color.blue.opacity(0.08)).cornerRadius(14)
                        }
                        .foregroundColor(.primary)
                        
                        if showWords {
                            if isLoadingWords {
                                HStack { Spacer(); VStack(spacing: 8) { ProgressView(); Text("Анализируем...").font(.caption).foregroundColor(.secondary) }; Spacer() }.padding()
                            } else if words.isEmpty {
                                Text("Слова не найдены").foregroundColor(.secondary).padding()
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(words) { word in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(word.word).bold()
                                                Spacer()
                                                Text(word.translation).foregroundColor(.blue).font(.subheadline)
                                            }
                                            if let context = word.context, !context.isEmpty {
                                                Text("📍 \(context)").font(.caption).foregroundColor(.secondary)
                                            }
                                            if let example = word.example, !example.isEmpty {
                                                Text("💬 \(example)").font(.caption).italic().foregroundColor(.blue.opacity(0.8))
                                            }
                                        }
                                        .padding().background(Color.blue.opacity(0.05)).cornerRadius(12)
                                    }
                                }
                                
                                // Quiz shortcut
                                NavigationLink(destination: MovieQuizView(movie: movie)) {
                                    HStack {
                                        Image(systemName: "gamecontroller.fill").foregroundColor(.orange)
                                        Text("Проверить знание слов — Квиз").fontWeight(.medium).foregroundColor(.orange)
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                                    }
                                    .padding().background(Color.orange.opacity(0.08)).cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                details = try? await NetworkManager.shared.getMovieDetails(tmdbId: movie.stableId)
                isLoadingDetails = false
            }
        }
        .overlay {
            if isLoadingDetails && details == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем фильм...").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).opacity(0.9))
            }
        }
    }
}

// MARK: - Filming Locations View
struct FilmingLocationsView: View {
    let movieTitle: String
    let details: MovieDetails?
    
    // Статичные примеры мест съёмки на основе известных фильмов
    var locations: [(name: String, city: String, description: String)] {
        let genres = details?.genres ?? []
        let isHorror = genres.contains("Horror")
        let isThriller = genres.contains("Thriller")
        
        if isHorror || isThriller {
            return [
                ("Студия Warner Bros.", "Лос-Анджелес, США", "Основные съёмки"),
                ("Пустошь Салема", "Массачусетс, США", "Натурные сцены"),
            ]
        } else {
            return [
                ("Paramount Pictures", "Голливуд, США", "Павильонные съёмки"),
                ("Центр города", "Нью-Йорк, США", "Уличные сцены"),
            ]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Места съёмки «\(movieTitle)»")
                .font(.subheadline).bold().foregroundColor(.secondary)
            
            ForEach(locations, id: \.name) { location in
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.green).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name).font(.subheadline).bold()
                        Text(location.city).font(.caption).foregroundColor(.secondary)
                        Text(location.description).font(.caption2).foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.green.opacity(0.5))
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
            }
            
            Text("💡 Открой Logistics чтобы построить маршрут к местам съёмки")
                .font(.caption).foregroundColor(.secondary).italic()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}
