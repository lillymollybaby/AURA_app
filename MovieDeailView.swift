import SwiftUI

// MARK: - Movie Detail View
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
    @State private var addedToWatchlist = false
    @State private var markedWatched = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: Backdrop
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = details?.backdrop_url, let url = URL(string: backdropURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                        }
                        .frame(height: 220)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color(.systemBackground)]),
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 180)
                    }
                }
                
                // MARK: Постер + основная инфа
                HStack(alignment: .top, spacing: 16) {
                    // Постер
                    if let posterURL = movie.poster_url, let url = URL(string: posterURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(Color.gray.opacity(0.3))
                                    .overlay(Image(systemName: "film").foregroundColor(.gray).font(.title))
                            }
                        }
                        .frame(width: 110, height: 165)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .offset(y: -40)
                    }
                    
                    // Инфо
                    VStack(alignment: .leading, spacing: 6) {
                        Text(movie.title)
                            .font(.title3)
                            .bold()
                            .lineLimit(2)
                        
                        if let originalTitle = details?.original_title, originalTitle != movie.title {
                            Text(originalTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            if let year = movie.year {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let runtime = details?.runtime {
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text("\(runtime) мин")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let rating = movie.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .bold()
                                    .font(.subheadline)
                                if let count = details?.vote_count {
                                    Text("(\(count))")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        if let genres = details?.genres, !genres.isEmpty {
                            Text(genres.prefix(3).joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.top, details?.backdrop_url != nil ? -20 : 16)
                
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: Кнопки действий
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                do {
                                    let _ = try await NetworkManager.shared.markWatched(tmdbId: movie.stableId)
                                    withAnimation { markedWatched = true }
                                } catch {}
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: markedWatched ? "checkmark.circle.fill" : "eye.fill")
                                Text(markedWatched ? "Просмотрено" : "Просмотрел")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(markedWatched ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            Task {
                                do {
                                    let _ = try await NetworkManager.shared.addToWatchlist(tmdbId: movie.stableId)
                                    withAnimation { addedToWatchlist = true }
                                } catch {}
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: addedToWatchlist ? "bookmark.fill" : "bookmark")
                                Text(addedToWatchlist ? "В списке" : "Watchlist")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(addedToWatchlist ? Color.green : Color(.systemGray5))
                            .foregroundColor(addedToWatchlist ? .white : .primary)
                            .cornerRadius(12)
                        }
                    }
                    
                    // MARK: Tagline
                    if let tagline = details?.tagline, !tagline.isEmpty {
                        Text("«\(tagline)»")
                            .italic()
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // MARK: Описание
                    if let overview = details?.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("О фильме")
                                .font(.headline)
                            Text(overview)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }
                    
                    // MARK: Режиссёр
                    if let directors = details?.directors, !directors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Режиссёр")
                                .font(.headline)
                            Text(directors.joined(separator: ", "))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // MARK: Актёры
                    if let cast = details?.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Актёры")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(cast, id: \.name) { actor in
                                        VStack(spacing: 6) {
                                            Group {
                                                if let profileURL = actor.profile_url, let url = URL(string: profileURL) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .success(let img):
                                                            img.resizable().aspectRatio(contentMode: .fill)
                                                        default:
                                                            Circle().fill(Color.gray.opacity(0.3))
                                                                .overlay(Image(systemName: "person").foregroundColor(.gray))
                                                        }
                                                    }
                                                } else {
                                                    Circle().fill(Color.gray.opacity(0.3))
                                                        .overlay(Image(systemName: "person").foregroundColor(.gray))
                                                }
                                            }
                                            .frame(width: 64, height: 64)
                                            .clipShape(Circle())
                                            .shadow(radius: 3)
                                            
                                            Text(actor.name)
                                                .font(.caption2)
                                                .bold()
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .frame(width: 72)
                                            
                                            Text(actor.character)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .frame(width: 72)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // MARK: AI Рецензия
                    VStack(spacing: 10) {
                        Button(action: {
                            withAnimation { showCritique.toggle() }
                            if critique.isEmpty && !isLoadingCritique {
                                isLoadingCritique = true
                                Task {
                                    let result = try? await NetworkManager.shared.getFilmCritique(tmdbId: movie.stableId)
                                    critique = result?["critique"] ?? "Не удалось загрузить рецензию"
                                    isLoadingCritique = false
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "theatermasks.fill")
                                    .foregroundColor(.purple)
                                Text("AI Рецензия")
                                    .fontWeight(.medium)
                                Spacer()
                                if isLoadingCritique {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: showCritique ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(14)
                        }
                        .foregroundColor(.primary)
                        
                        if showCritique && !critique.isEmpty {
                            Text(critique)
                                .font(.body)
                                .lineSpacing(4)
                                .padding()
                                .background(Color.purple.opacity(0.05))
                                .cornerRadius(12)
                        }
                    }
                    
                    // MARK: Слова из фильма
                    VStack(spacing: 10) {
                        Button(action: {
                            withAnimation { showWords.toggle() }
                            if words.isEmpty && !isLoadingWords {
                                isLoadingWords = true
                                Task {
                                    let result = try? await NetworkManager.shared.getMovieWords(tmdbId: movie.stableId)
                                    words = result?.words ?? []
                                    isLoadingWords = false
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "textformat.abc")
                                    .foregroundColor(.blue)
                                Text("Слова из фильма")
                                    .fontWeight(.medium)
                                Spacer()
                                if isLoadingWords {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: showWords ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(14)
                        }
                        .foregroundColor(.primary)
                        
                        if showWords {
                            if isLoadingWords {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView()
                                        Text("Анализируем диалоги...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                            } else if words.isEmpty {
                                Text("Слова не найдены")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(words) { word in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(word.word)
                                                    .bold()
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Text(word.translation)
                                                    .foregroundColor(.blue)
                                                    .font(.subheadline)
                                            }
                                            if let context = word.context, !context.isEmpty {
                                                Text("📍 \(context)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            if let example = word.example, !example.isEmpty {
                                                Text("💬 \(example)")
                                                    .font(.caption)
                                                    .italic()
                                                    .foregroundColor(.blue.opacity(0.8))
                                            }
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.05))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
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
                    Text("Загружаем фильм...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.8))
            }
        }
    }
}
