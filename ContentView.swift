import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            LogisticsView().tabItem { Image(systemName: "location.fill"); Text("Logistics") }.tag(0)
            LanguagesView().tabItem { Image(systemName: "character.book.closed.fill"); Text("Languages") }.tag(1)
            CinemaView().tabItem { Image(systemName: "film.fill"); Text("Cinema") }.tag(2)
            FoodView().tabItem { Image(systemName: "fork.knife"); Text("Food") }.tag(3)
            ProfileView().tabItem { Image(systemName: "person.fill"); Text("Profile") }.tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - PROFILE VIEW
struct ProfileView: View {
    @State private var user: UserResponse?
    @State private var showLogoutAlert = false
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.15)).frame(width: 60, height: 60)
                            Text(initials).font(.title2.bold()).foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user?.full_name ?? "User").font(.headline)
                            Text(user?.email ?? "").font(.caption).foregroundColor(.secondary)
                        }
                    }.padding(.vertical, 8)
                }
                Section("Settings") {
                    HStack { Label("Calorie Goal", systemImage: "target"); Spacer(); Text("\(user?.calorie_goal ?? 2200) kcal").foregroundColor(.secondary) }
                    HStack { Label("Notifications", systemImage: "bell.fill"); Spacer(); Text("On").foregroundColor(.secondary) }
                }
                Section {
                    Button(role: .destructive) { showLogoutAlert = true } label: {
                        HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Sign Out") }
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out?", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    AuthStorage.shared.logout()
                    NotificationCenter.default.post(name: .didLogout, object: nil)
                }
            }
        }
        .task { if let u = try? await NetworkManager.shared.getMe() { user = u } }
    }
    var initials: String {
        guard let name = user?.full_name, !name.isEmpty else { return "?" }
        return String(name.prefix(1).uppercased())
    }
}

// MARK: - LOGISTICS VIEW
struct LogisticsView: View {
    @State private var searchQuery = ""
    @State private var places: [PlaceResult] = []
    @State private var trafficAdvice: TrafficAdviceResponse?
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search places...", text: $searchQuery)
                            .onSubmit { Task { await searchPlaces() } }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Traffic Advice
                    if let advice = trafficAdvice {
                        TrafficAdviceBanner(advice: advice)
                            .padding(.horizontal).padding(.top, 12)
                    }

                    // Live Traffic Card (static but pretty)
                    LiveTrafficCard().padding(.horizontal).padding(.top, 12)

                    // Search Results
                    if isSearching {
                        ProgressView("Searching...").padding(.top, 20)
                    } else if !places.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse").foregroundColor(.secondary)
                                Text("Results").font(.headline)
                                Spacer()
                                Text("\(places.count) found").font(.caption).foregroundColor(.secondary)
                            }.padding(.horizontal).padding(.top, 20).padding(.bottom, 12)

                            ForEach(Array(places.enumerated()), id: \.offset) { idx, place in
                                PlaceRow(place: place)
                                    .padding(.horizontal)
                                if idx < places.count - 1 { Divider().padding(.horizontal) }
                            }
                        }
                    } else {
                        // Default routes when no search
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch").foregroundColor(.secondary)
                                Text("Today's Route").font(.headline)
                            }.padding(.horizontal).padding(.top, 20).padding(.bottom, 12)
                            RouteItemView(icon: "briefcase.fill", iconColor: .orange, title: "Morning Standup", subtitle: "Office — 3rd Floor", time: "9:00", driveTime: "22 min", parking: "+3 park", statusText: "On Time", statusColor: .green, note: "Light traffic on your usual route", noteColor: Color.blue.opacity(0.15), noteIcon: "sparkle", noteIconColor: .blue)
                            RouteItemView(icon: "cross.fill", iconColor: .red, title: "Dentist Appointment", subtitle: "Dr. Klein — 45 Oak Ave", time: "11:30", driveTime: "18 min", parking: "+5 park", statusText: "Leave Now", statusColor: .red, note: "Leave by 11:05 — accident on Main St adds 7 min", noteColor: Color.red.opacity(0.12), noteIcon: "exclamationmark.triangle.fill", noteIconColor: .red)
                            RouteItemView(icon: "building.columns.fill", iconColor: .green, title: "Bank Transfer", subtitle: "Chase — Downtown Branch", time: "14:15", driveTime: "14 min", parking: "+4 park", statusText: "Delayed", statusColor: .orange, note: "Re-routed via Elm St — saves 6 min", noteColor: Color.blue.opacity(0.12), noteIcon: "sparkle", noteIconColor: .blue)
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Logistics").navigationBarTitleDisplayMode(.large)
        }
        .task {
            if let advice = try? await NetworkManager.shared.getTrafficAdvice(destination: "work") {
                trafficAdvice = advice
            }
        }
    }

    func searchPlaces() async {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        if let results = try? await NetworkManager.shared.searchPlace(query: searchQuery) {
            places = results
        }
        // Also get traffic advice for the search
        if let advice = try? await NetworkManager.shared.getTrafficAdvice(destination: searchQuery) {
            trafficAdvice = advice
        }
        isSearching = false
    }
}

struct TrafficAdviceBanner: View {
    let advice: TrafficAdviceResponse
    var bannerColor: Color {
        if advice.traffic_status.contains("сильн") { return .red }
        if advice.traffic_status.contains("умеренн") { return .orange }
        return .green
    }
    var body: some View {
        HStack {
            Image(systemName: "car.fill").foregroundColor(.white).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Traffic: \(advice.traffic_status)").font(.headline).foregroundColor(.white)
                Text(advice.advice).font(.caption).foregroundColor(.white.opacity(0.9)).lineLimit(3)
            }
            Spacer()
        }.padding().background(bannerColor).cornerRadius(14)
    }
}

struct PlaceRow: View {
    let place: PlaceResult
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: "mappin").foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).font(.subheadline).fontWeight(.semibold)
                if let address = place.address, !address.isEmpty {
                    Text(address).font(.caption).foregroundColor(.secondary)
                }
                if let type = place.type, !type.isEmpty {
                    Text(type).font(.caption2).foregroundColor(.blue)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }.padding(.vertical, 8)
    }
}

struct LeaveNowBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Leave Now").font(.headline).foregroundColor(.white)
                Text("Leave by 11:05 — accident on Main St adds 7 min").font(.caption).foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("18 min").font(.title2).fontWeight(.bold).foregroundColor(.white)
                Text("5.2 km").font(.caption).foregroundColor(.white.opacity(0.9))
            }
        }.padding().background(Color.red).cornerRadius(14)
    }
}

struct LiveTrafficCard: View {
    let routes = [("I-90 West", Color.green), ("Main Street", Color.red), ("Oak Avenue", Color.orange), ("Highway 101", Color.green), ("Elm Street", Color.yellow)]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "car.fill").foregroundColor(.primary)
                Text("Live Traffic").font(.headline)
                Spacer()
                Text("84 min total").font(.caption).foregroundColor(.secondary)
            }
            ForEach(routes, id: \.0) { route in
                HStack(spacing: 8) {
                    Circle().fill(route.1).frame(width: 8, height: 8)
                    Text(route.0).font(.subheadline)
                    Spacer()
                    RoundedRectangle(cornerRadius: 3).fill(route.1.opacity(0.3)).frame(width: 80, height: 6)
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct RouteItemView: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String
    let time: String; let driveTime: String; let parking: String
    let statusText: String; let statusColor: Color
    let note: String?; let noteColor: Color; let noteIcon: String; let noteIconColor: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 40, height: 40)
                    .overlay(Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 16)))
                Rectangle().fill(Color(.systemGray5)).frame(width: 2).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(title).font(.headline); Spacer(); StatusBadge(text: statusText, color: statusColor) }
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label(time, systemImage: "clock").font(.caption).foregroundColor(.secondary)
                    Label(driveTime, systemImage: "car.fill").font(.caption).foregroundColor(.secondary)
                    Label(parking, systemImage: "p.circle").font(.caption).foregroundColor(.secondary)
                }
                if let note = note {
                    HStack(spacing: 6) {
                        if !noteIcon.isEmpty { Image(systemName: noteIcon).font(.caption2).foregroundColor(noteIconColor) }
                        Text(note).font(.caption).foregroundColor(noteIconColor == .red ? .red : .blue)
                    }.padding(.horizontal, 10).padding(.vertical, 6).background(noteColor).cornerRadius(8)
                }
                Spacer(minLength: 16)
            }
        }.padding(.horizontal)
    }
}

struct StatusBadge: View {
    let text: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            if color == .red { Image(systemName: "exclamationmark.triangle.fill").font(.caption2) }
            else if color == .green { Image(systemName: "checkmark.circle.fill").font(.caption2) }
            Text(text).font(.caption).fontWeight(.semibold)
        }
        .foregroundColor(color == .orange ? .orange : .white)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(color == .orange ? Color.orange.opacity(0.15) : color).cornerRadius(20)
    }
}

// MARK: - LANGUAGES VIEW
struct LanguagesView: View {
    @State private var streak: StreakResponse?
    @State private var vocab: [VocabResponse] = []
    let days = ["S", "F", "T", "W", "T", "M", "S"]
    let completed = [true, true, true, true, true, false, true]
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🇩🇪").font(.largeTitle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("German").font(.title2).fontWeight(.bold)
                                HStack(spacing: 6) {
                                    Text("B1").font(.caption).fontWeight(.bold).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.15)).foregroundColor(.blue).cornerRadius(4)
                                    Text("Intermediate").font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(streak?.streak_days ?? 0)").font(.title).fontWeight(.bold).foregroundColor(.orange)
                                Text("day streak").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "chart.bar.fill").foregroundColor(.secondary)
                            Text("Weekly Progress").font(.headline)
                            Spacer()
                            Text("\(streak?.learned_words ?? 0)/\(streak?.total_words ?? 0) words").font(.caption).foregroundColor(.secondary)
                        }
                        ProgressView(value: Double(streak?.progress_percent ?? 0), total: 100).tint(.blue).scaleEffect(x: 1, y: 1.5, anchor: .center)
                        HStack {
                            ForEach(0..<7) { i in
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle().fill(completed[i] ? Color.blue : Color(.systemGray5)).frame(width: 28, height: 28)
                                        if completed[i] { Image(systemName: "checkmark").font(.caption2).fontWeight(.bold).foregroundColor(.white) }
                                    }
                                    Text(days[i]).font(.caption2).foregroundColor(.secondary)
                                }.frame(maxWidth: .infinity)
                            }
                        }
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    if !vocab.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "books.vertical.fill").foregroundColor(.secondary)
                                Text("My Vocabulary").font(.headline)
                                Spacer()
                                Text("\(vocab.count) words").font(.caption).foregroundColor(.blue)
                            }
                            ForEach(vocab.prefix(10), id: \.id) { word in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(word.word).font(.subheadline).fontWeight(.semibold)
                                        Text(word.translation).font(.caption).foregroundColor(.secondary)
                                        if let example = word.example, !example.isEmpty {
                                            Text(example).font(.caption2).foregroundColor(.blue).italic()
                                        }
                                    }
                                    Spacer()
                                    if word.learned {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    } else {
                                        Button {
                                            Task { try? await NetworkManager.shared.markWordLearned(wordId: word.id) }
                                        } label: {
                                            Image(systemName: "circle").foregroundColor(.secondary)
                                        }
                                    }
                                }.padding(.vertical, 4)
                            }
                        }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "brain.head.profile").foregroundColor(.secondary); Text("Smart Lessons").font(.headline) }
                        SmartLessonCard(icon: "textformat.abc", iconColor: .blue, title: "At the Dentist", subtitle: "Linked to your 11:30 appointment", tag: "Logistics", tagColor: .blue, isNew: true, accent: .blue)
                        SmartLessonCard(icon: "film.fill", iconColor: .purple, title: "Film Dialogue: Metropolis", subtitle: "Practice lines from Fritz Lang's classic", tag: "Cinema", tagColor: .purple, isNew: false, accent: .purple)
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    Spacer(minLength: 20)
                }.padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground)).navigationTitle("Languages").navigationBarTitleDisplayMode(.large)
        }
        .task {
            if let v = try? await NetworkManager.shared.getVocabulary() { vocab = v }
            if let s: StreakResponse = try? await NetworkManager.shared.request("/languages/streak") { streak = s }
        }
    }
}

struct SmartLessonCard: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String
    let tag: String; let tagColor: Color; let isNew: Bool; let accent: Color
    var body: some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 10).fill(iconColor.opacity(0.12)).frame(width: 44, height: 44); Image(systemName: icon).foregroundColor(iconColor) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline).fontWeight(.semibold)
                    if isNew { Text("NEW").font(.caption2).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue).cornerRadius(4) }
                }
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) { Text(tag).font(.caption).foregroundColor(tagColor); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }
        }
        .padding(.vertical, 4)
        .overlay(Rectangle().fill(accent).frame(width: 3).padding(.vertical, 4), alignment: .leading)
        .padding(.leading, 8)
    }
}

// MARK: - CINEMA VIEW
struct CinemaView: View {
    @State private var trending: [MovieResponse] = []
    @State private var myMovies: [MovieResponse] = []
    @State private var searchQuery = ""
    @State private var searchResults: [MovieResponse] = []
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search movies...", text: $searchQuery).onSubmit { Task { await searchMovies() } }
                    }.padding(10).background(Color(.systemBackground)).cornerRadius(12).shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2).padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            GenreChip(title: "All", isSelected: true)
                            GenreChip(title: "⚡ Thriller", isSelected: false)
                            GenreChip(title: "🎭 Drama", isSelected: false)
                            GenreChip(title: "✨ Sci-Fi", isSelected: false)
                            GenreChip(title: "😂 Comedy", isSelected: false)
                        }.padding(.horizontal)
                    }

                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Image(systemName: "magnifyingglass").foregroundColor(.secondary); Text("Results").font(.headline) }.padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(searchResults, id: \.stableId) { m in
                                        MovieCard(movie: m, color: Color(red: 0.1, green: 0.12, blue: 0.2))
                                    }
                                }.padding(.horizontal)
                            }
                        }
                    }

                    if !trending.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Image(systemName: "flame.fill").foregroundColor(.secondary); Text("Trending").font(.headline) }.padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(trending, id: \.stableId) { m in
                                        MovieCard(movie: m, color: Color(red: 0.1, green: 0.12, blue: 0.25))
                                    }
                                }.padding(.horizontal)
                            }
                        }
                    }

                    if !myMovies.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Image(systemName: "play.circle.fill").foregroundColor(.secondary); Text("My List").font(.headline) }.padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(myMovies, id: \.stableId) { m in
                                        MovieCard(movie: m, color: Color(red: 0.15, green: 0.1, blue: 0.2))
                                    }
                                }.padding(.horizontal)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "bubble.left.and.bubble.right.fill").foregroundColor(.secondary); Text("Film Critic AI").font(.headline) }
                        CriticQuestion(category: "Symbolism", question: "Why does the Sunken Place represent?")
                        CriticQuestion(category: "Technique", question: "How does the aspect ratio change in Grand Budapest?")
                        CriticQuestion(category: "Science", question: "What's the Sapir-Whorf hypothesis in Arrival?")
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    Spacer(minLength: 20)
                }.padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground)).navigationTitle("Cinema").navigationBarTitleDisplayMode(.large)
        }
        .task {
            if let t = try? await NetworkManager.shared.getTrending() { trending = t }
            if let m = try? await NetworkManager.shared.getMyMovies() { myMovies = m }
        }
    }
    func searchMovies() async {
        if let r = try? await NetworkManager.shared.searchMovies(query: searchQuery) { searchResults = r }
    }
}

struct GenreChip: View {
    let title: String; let isSelected: Bool
    var body: some View {
        Text(title).font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary).padding(.horizontal, 14).padding(.vertical, 7)
            .background(isSelected ? Color.blue : Color(.systemBackground)).cornerRadius(20)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct MovieCard: View {
    let movie: MovieResponse
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let posterUrl = movie.poster_url, let url = URL(string: posterUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(color)
                            .overlay(Image(systemName: "sparkles").font(.largeTitle).foregroundColor(.white.opacity(0.3)))
                    }
                    .frame(width: 150, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(color).frame(width: 150, height: 200)
                        .overlay(
                            VStack {
                                Spacer()
                                Image(systemName: "sparkles").font(.largeTitle).foregroundColor(.white.opacity(0.3))
                                Spacer()
                                Text(movie.title).font(.subheadline).fontWeight(.bold).foregroundColor(.white).multilineTextAlignment(.center).padding(.horizontal, 8).padding(.bottom, 16)
                            }
                        )
                }
            }.frame(width: 150, height: 200)
            Text(movie.title).font(.caption).fontWeight(.semibold).lineLimit(1).padding(.top, 6)
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                Text("\(movie.rating.map { String(format: "%.1f", $0) } ?? "—") · \(movie.year ?? "")").font(.caption).foregroundColor(.secondary)
            }
        }.frame(width: 150)
    }
}

struct CriticQuestion: View {
    let category: String; let question: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category).font(.caption).foregroundColor(.purple)
                Text(question).font(.subheadline).fontWeight(.medium).foregroundColor(.blue)
            }
            Spacer()
            Image(systemName: "chevron.down").foregroundColor(.secondary).font(.caption)
        }.padding(.vertical, 6)
    }
}

// MARK: - FOOD VIEW
struct FoodView: View {
    @State private var summary: DailySummaryResponse?
    @State private var meals: [MealResponse] = []
    @State private var showCamera = false
    @State private var dinnerIdeas: String?
    var progress: Double {
        guard let s = summary, s.calorie_goal > 0 else { return 0 }
        return min(s.total_calories / Double(s.calorie_goal), 1.0)
    }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        HStack(alignment: .center, spacing: 20) {
                            ZStack {
                                Circle().stroke(Color(.systemGray5), lineWidth: 8).frame(width: 90, height: 90)
                                Circle().trim(from: 0, to: progress)
                                    .stroke(AngularGradient(colors: [.blue, .cyan], center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 90, height: 90).rotationEffect(.degrees(-90))
                                VStack(spacing: 0) {
                                    Text("\(Int(summary?.total_calories ?? 0))").font(.system(size: 18, weight: .bold))
                                    Text("kcal").font(.caption2).foregroundColor(.secondary)
                                    Text("of \(summary?.calorie_goal ?? 2200)").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            HStack(spacing: 16) {
                                MacroBar(value: Int(summary?.total_proteins ?? 0), unit: "g", label: "Protein", color: .blue)
                                MacroBar(value: Int(summary?.total_carbs ?? 0), unit: "g", label: "Carbs", color: .orange)
                                MacroBar(value: Int(summary?.total_fats ?? 0), unit: "g", label: "Fat", color: .purple)
                            }
                        }
                        HStack(spacing: 8) {
                            MetricBadge(icon: "bolt.fill", iconColor: .yellow, label: "Energy", value: "72%", color: .yellow)
                            MetricBadge(icon: "leaf.fill", iconColor: .green, label: "Satiety", value: "65%", color: .green)
                            MetricBadge(icon: "drop.fill", iconColor: .blue, label: "Balance", value: "81%", color: .blue)
                        }
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    // AI Advice
                    if let advice = summary?.ai_advice, !advice.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundColor(.blue)
                            Text(advice).font(.caption).foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "fork.knife").foregroundColor(.secondary); Text("Today's Meals").font(.headline) }
                        if meals.isEmpty { Text("No meals logged today").font(.subheadline).foregroundColor(.secondary).padding(.vertical, 8) }
                        ForEach(Array(meals.enumerated()), id: \.element.id) { idx, meal in
                            if idx > 0 { Divider() }
                            MealRow(emoji: mealEmoji(meal.meal_type ?? "snack"), bgColor: mealColor(meal.meal_type ?? "snack"), title: meal.name,
                                description: "\(Int(meal.proteins))g protein · \(Int(meal.carbs))g carbs",
                                time: formatTime(meal.eaten_at), calories: "\(Int(meal.calories)) kcal",
                                protein: "\(Int(meal.proteins))g P", carbs: "\(Int(meal.carbs))g C", tip: meal.ai_analysis)
                        }
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    // Dinner Ideas
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(.secondary)
                            Text("Dinner Ideas").font(.headline)
                            Spacer()
                            Button("Get Ideas") {
                                Task {
                                    if let ideas = try? await NetworkManager.shared.getDinnerIdeas() {
                                        dinnerIdeas = ideas.ideas
                                    }
                                }
                            }.font(.caption).foregroundColor(.blue)
                        }
                        if let ideas = dinnerIdeas {
                            Text(ideas).font(.subheadline).foregroundColor(.secondary)
                        } else {
                            DinnerIdeaRow(emoji: "🐟", title: "Salmon & Quinoa Bowl", subtitle: "You're short on protein today", calories: "520 kcal")
                            Divider()
                            DinnerIdeaRow(emoji: "🍠", title: "Sweet Potato Stir-Fry", subtitle: "Complex carbs for sustained energy", calories: "380 kcal")
                            Divider()
                            DinnerIdeaRow(emoji: "🥑", title: "Avocado Toast", subtitle: "Healthy fats to hit your daily target", calories: "310 kcal")
                        }
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "heart.text.square.fill").foregroundColor(.secondary); Text("Health Sync").font(.headline) }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            HealthMetric(icon: "figure.walk", iconColor: .red, value: "8,432", label: "Steps", note: "On pace — 1,568 more to hit 10K")
                            HealthMetric(icon: "flame.fill", iconColor: .orange, value: "380 kcal", label: "Active Calories", note: "Add ~120 kcal to your dinner plan")
                            HealthMetric(icon: "bed.double.fill", iconColor: .indigo, value: "7h 12m", label: "Sleep", note: "Good rest — metabolism on track")
                            HealthMetric(icon: "heart.fill", iconColor: .red, value: "68 bpm", label: "Heart Rate", note: "")
                        }
                    }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2).padding(.horizontal)

                    Spacer(minLength: 20)
                }.padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground)).navigationTitle("Food").navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera.fill").font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                            .padding(8).background(Color(.systemBackground)).clipShape(Circle()).shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
        .task {
            if let s = try? await NetworkManager.shared.getTodaySummary() { summary = s }
            if let m = try? await NetworkManager.shared.getMealHistory() { meals = m }
        }
    }
    func mealEmoji(_ type: String) -> String { switch type { case "breakfast": return "🌅"; case "lunch": return "☀️"; case "dinner": return "🌙"; default: return "🍽️" } }
    func mealColor(_ type: String) -> Color { switch type { case "breakfast": return Color.orange.opacity(0.12); case "lunch": return Color.yellow.opacity(0.12); case "dinner": return Color.blue.opacity(0.12); default: return Color.gray.opacity(0.12) } }
    func formatTime(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
        }
        let formatter2 = ISO8601DateFormatter()
        if let date = formatter2.date(from: dateStr) {
            let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
        }
        return ""
    }
}

struct MacroBar: View {
    let value: Int; let unit: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(width: 8, height: 60)
                .overlay(VStack { Spacer(); RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 8, height: min(CGFloat(value) / 150.0 * 60, 60)) })
            Text("\(value)\(unit)").font(.caption).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

struct MetricBadge: View {
    let icon: String; let iconColor: Color; let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) { Image(systemName: icon).font(.caption2).foregroundColor(iconColor); Text(label).font(.caption2).foregroundColor(.secondary) }
            ProgressView(value: Double(value.replacingOccurrences(of: "%", with: "")) ?? 0, total: 100).tint(color).scaleEffect(x: 1, y: 1.2, anchor: .center)
            Text(value).font(.caption).fontWeight(.semibold).foregroundColor(color)
        }.padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity).background(color.opacity(0.08)).cornerRadius(10)
    }
}

struct MealRow: View {
    let emoji: String; let bgColor: Color; let title: String; let description: String
    let time: String; let calories: String; let protein: String; let carbs: String; let tip: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack { RoundedRectangle(cornerRadius: 10).fill(bgColor).frame(width: 44, height: 44); Text(emoji).font(.title3) }
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text(title).font(.subheadline).fontWeight(.semibold); Spacer(); Text(time).font(.caption).foregroundColor(.secondary) }
                    Text(description).font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Label(calories, systemImage: "flame").font(.caption).foregroundColor(.secondary)
                        Circle().fill(Color.blue).frame(width: 6, height: 6); Text(protein).font(.caption).foregroundColor(.blue)
                        Circle().fill(Color.orange).frame(width: 6, height: 6); Text(carbs).font(.caption).foregroundColor(.orange)
                    }
                }
            }
            if let tip = tip, !tip.isEmpty {
                HStack(spacing: 6) { Image(systemName: "sparkle").font(.caption2).foregroundColor(.blue); Text(tip).font(.caption).foregroundColor(.blue) }
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.blue.opacity(0.08)).cornerRadius(8)
            }
        }
    }
}

struct DinnerIdeaRow: View {
    let emoji: String; let title: String; let subtitle: String; let calories: String
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title2).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline).fontWeight(.semibold); Text(subtitle).font(.caption).foregroundColor(.secondary) }
            Spacer()
            Text(calories).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
        }
    }
}

struct HealthMetric: View {
    let icon: String; let iconColor: Color; let value: String; let label: String; let note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundColor(iconColor).font(.title3)
            Text(value).font(.title3).fontWeight(.bold)
            Text(label).font(.caption).foregroundColor(.secondary)
            if !note.isEmpty { Text(note).font(.caption2).foregroundColor(.secondary) }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.systemGroupedBackground)).cornerRadius(12)
    }
}
