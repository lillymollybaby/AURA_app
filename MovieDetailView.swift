import SwiftUI

struct MovieDetailView: View {
    let tmdbId: Int
    let title: String
    let isWatched: Bool
    let vm: CinemaViewModel  // shared VM to update lists instantly

    @State private var details: MovieDetails? = nil
    @State private var words: [MovieWord] = []
    @State private var facts: String = ""
    @State private var isLoadingDetails = true
    @State private var isLoadingWords = false
    @State private var isLoadingFacts = false
    @State private var showWords = false
    @State private var showFacts = false
    @State private var overviewExpanded = false
    @State private var showCrewTab = false
    @State private var localWatched: Bool = false
    @State private var localInWatchlist: Bool = false
    @State private var isMarkingWatched = false
    @State private var isAddingWatchlist = false

    var effectivelyWatched: Bool { isWatched || localWatched }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Backdrop
                ZStack(alignment: .bottom) {
                    if let backdropURL = details?.backdrop_url, let url = URL(string: backdropURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                            default: backdropPlaceholder
                            }
                        }
                        .frame(height: 220).clipped()
                    } else {
                        backdropPlaceholder.frame(height: 160)
                    }
                    LinearGradient(
                        colors: [.clear, Color(.systemGroupedBackground)],
                        startPoint: .center, endPoint: .bottom
                    )
                    .frame(height: details?.backdrop_url != nil ? 220 : 160)
                }

                // MARK: Poster + Info
                HStack(alignment: .bottom, spacing: 16) {
                    if let posterURL = details?.poster_url, let url = URL(string: posterURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                            default: Rectangle().fill(Color.gray.opacity(0.3))
                                    .overlay(Image(systemName: "film").foregroundColor(.gray).font(.title))
                            }
                        }
                        .frame(width: 100, height: 150).cornerRadius(12)
                        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                        .offset(y: -24)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.title3).bold().lineLimit(2)
                        if let orig = details?.original_title, orig != title {
                            Text(orig).font(.caption).foregroundColor(.secondary)
                        }
                        HStack(spacing: 6) {
                            if let year = details?.year { Text(year).font(.caption).foregroundColor(.secondary) }
                            if let runtime = details?.runtime {
                                Text("·").foregroundColor(.secondary)
                                Text("\(runtime) мин").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        if let rating = details?.rating {
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
                    .padding(.bottom, 6)
                }
                .padding(.horizontal)
                .padding(.top, -10)

                VStack(alignment: .leading, spacing: 16) {

                    // MARK: Action Buttons
                    HStack(spacing: 10) {
                        // Mark as watched
                        Button {
                            guard !effectivelyWatched && !isMarkingWatched else { return }
                            isMarkingWatched = true
                            Task {
                                await vm.markWatched(tmdbId: tmdbId)
                                withAnimation { localWatched = true }
                                NotificationManager.shared.sendMovieLoggedNotification(movieTitle: title)
                                isMarkingWatched = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isMarkingWatched {
                                    ProgressView().scaleEffect(0.8).tint(.white)
                                } else {
                                    Image(systemName: effectivelyWatched ? "checkmark.circle.fill" : "eye.fill")
                                }
                                Text(effectivelyWatched ? "Просмотрено" : "Просмотрел")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(effectivelyWatched ? Color.green : Color.blue)
                            .foregroundColor(.white).cornerRadius(14)
                        }
                        .disabled(effectivelyWatched || isMarkingWatched)

                        // Add to watchlist
                        Button {
                            guard !localInWatchlist && !isAddingWatchlist else { return }
                            isAddingWatchlist = true
                            Task {
                                await vm.addToWatchlist(tmdbId: tmdbId)
                                withAnimation { localInWatchlist = true }
                                isAddingWatchlist = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isAddingWatchlist {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: localInWatchlist ? "bookmark.fill" : "bookmark")
                                }
                                Text(localInWatchlist ? "В списке" : "Watchlist")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(localInWatchlist ? Color.green : Color(.systemGray5))
                            .foregroundColor(localInWatchlist ? .white : .primary).cornerRadius(14)
                        }
                        .disabled(localInWatchlist || isAddingWatchlist)
                    }

                    // MARK: Tagline
                    if let tagline = details?.tagline, !tagline.isEmpty {
                        Text("«\(tagline)»").italic().foregroundColor(.secondary)
                            .font(.subheadline).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }

                    // MARK: Overview
                    if let overview = details?.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("О фильме").font(.headline)
                            Text(overview)
                                .font(.body).foregroundColor(.secondary).lineSpacing(4)
                                .lineLimit(overviewExpanded ? nil : 3)
                            Button {
                                withAnimation(.spring(response: 0.3)) { overviewExpanded.toggle() }
                            } label: {
                                Text(overviewExpanded ? "Свернуть" : "Развернуть")
                                    .font(.caption).foregroundColor(.blue)
                            }
                        }
                    }

                    // MARK: Cast & Crew
                    if let cast = details?.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 0) {
                                ForEach(["Актёры", "Съёмочная группа"], id: \.self) { tab in
                                    let isCrew = tab == "Съёмочная группа"
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { showCrewTab = isCrew }
                                    } label: {
                                        Text(tab)
                                            .font(.subheadline)
                                            .fontWeight(showCrewTab == isCrew ? .bold : .regular)
                                            .foregroundColor(showCrewTab == isCrew ? .primary : .secondary)
                                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                                            .background(showCrewTab == isCrew ? Color(.systemBackground) : Color.clear)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(4).background(Color(.systemGray6)).cornerRadius(14)

                            if !showCrewTab {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(cast, id: \.name) { actor in
                                            VStack(spacing: 5) {
                                                Group {
                                                    if let profileURL = actor.profile_url, let url = URL(string: profileURL) {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                                                            default: initialsCircle(actor.name)
                                                            }
                                                        }
                                                    } else {
                                                        initialsCircle(actor.name)
                                                    }
                                                }
                                                .frame(width: 64, height: 64).clipShape(Circle()).shadow(radius: 2)
                                                Text(actor.name).font(.caption2).bold()
                                                    .multilineTextAlignment(.center).lineLimit(2).frame(width: 72)
                                                Text(actor.character).font(.caption2).foregroundColor(.secondary)
                                                    .multilineTextAlignment(.center).lineLimit(2).frame(width: 72)
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    if let directors = details?.directors, !directors.isEmpty {
                                        CrewRow(role: "Режиссёр", names: directors)
                                    }
                                    if let writers = details?.writers, !writers.isEmpty {
                                        CrewRow(role: "Сценарист", names: writers)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // MARK: Spoiler-locked content
                    if effectivelyWatched {
                        VStack(spacing: 10) {
                            // Facts
                            DisclosureButton(
                                icon: "sparkles", iconColor: .yellow,
                                title: "Интересные факты",
                                isLoading: isLoadingFacts,
                                isExpanded: showFacts
                            ) {
                                withAnimation { showFacts.toggle() }
                                if facts.isEmpty && !isLoadingFacts {
                                    isLoadingFacts = true
                                    Task {
                                        facts = (try? await NetworkManager.shared.getFilmCritique(tmdbId: tmdbId)) ?? ""
                                        isLoadingFacts = false
                                    }
                                }
                            }

                            if showFacts && !facts.isEmpty {
                                Text(facts).font(.body).lineSpacing(4).padding()
                                    .background(Color.yellow.opacity(0.05)).cornerRadius(12)
                                    .transition(.opacity)
                            }

                            // Words
                            DisclosureButton(
                                icon: "textformat.abc", iconColor: .blue,
                                title: "Слова из фильма",
                                isLoading: isLoadingWords,
                                isExpanded: showWords
                            ) {
                                withAnimation { showWords.toggle() }
                                if words.isEmpty && !isLoadingWords {
                                    isLoadingWords = true
                                    Task {
                                        words = (try? await NetworkManager.shared.getMovieWords(tmdbId: tmdbId))?.words ?? []
                                        isLoadingWords = false
                                    }
                                }
                            }

                            if showWords {
                                VStack(spacing: 8) {
                                    ForEach(words) { word in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(word.word).bold()
                                                Spacer()
                                                Text(word.translation).foregroundColor(.blue).font(.subheadline)
                                            }
                                            if let example = word.example, !example.isEmpty {
                                                Text("💬 \(example)").font(.caption).italic().foregroundColor(.blue.opacity(0.8))
                                            }
                                        }
                                        .padding().background(Color.blue.opacity(0.05)).cornerRadius(10)
                                    }

                                    // Quiz — only show when words are loaded
                                    if !words.isEmpty {
                                        NavigationLink(destination: MovieQuizView(movie: MovieResponse(
                                            id: nil, tmdb_id: tmdbId, title: title,
                                            year: details?.year, rating: details?.rating,
                                            poster_url: details?.poster_url, watched: true, review: nil
                                        ))) {
                                            HStack {
                                                Image(systemName: "gamecontroller.fill").foregroundColor(.orange)
                                                Text("Квиз по словам фильма").fontWeight(.medium).foregroundColor(.orange)
                                                Spacer()
                                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                                            }
                                            .padding().background(Color.orange.opacity(0.08)).cornerRadius(12)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                    } else {
                        // Locked
                        HStack(spacing: 14) {
                            Image(systemName: "lock.fill").font(.title2).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Факты, слова и квиз").font(.subheadline).fontWeight(.semibold)
                                Text("Доступны после просмотра — без спойлеров")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6)).cornerRadius(14)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Check if already in watchlist
            localInWatchlist = vm.watchlist.contains { $0.stableId == tmdbId }
            Task {
                details = try? await NetworkManager.shared.getMovieDetails(tmdbId: tmdbId)
                isLoadingDetails = false
            }
        }
        .overlay {
            if isLoadingDetails && details == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем...").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).opacity(0.9))
            }
        }
    }

    func initialsCircle(_ name: String) -> some View {
        Circle()
            .fill(LinearGradient(colors: [Color(red:0.2,green:0.4,blue:0.8), Color(red:0.4,green:0.2,blue:0.8)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Text(String(name.prefix(1))).font(.headline).bold().foregroundColor(.white))
    }

    var backdropPlaceholder: some View {
        Rectangle().fill(LinearGradient(
            colors: [Color(red:0.05,green:0.05,blue:0.2), Color(red:0.1,green:0.05,blue:0.3)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
    }
}

// MARK: - Disclosure Button
struct DisclosureButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let isLoading: Bool
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundColor(iconColor)
                Text(title).fontWeight(.medium)
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.8) }
                else { Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.secondary) }
            }
            .padding().background(iconColor.opacity(0.08)).cornerRadius(14)
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Crew Row
struct CrewRow: View {
    let role: String
    let names: [String]
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: role == "Режиссёр" ? "camera.fill" : "pencil").foregroundColor(.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(role).font(.caption).foregroundColor(.secondary)
                Text(names.joined(separator: ", ")).font(.subheadline).bold()
            }
            Spacer()
        }
        .padding().background(Color.purple.opacity(0.05)).cornerRadius(12)
    }
}
