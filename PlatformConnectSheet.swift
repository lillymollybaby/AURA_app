import SwiftUI

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
