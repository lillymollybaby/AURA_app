import SwiftUI

struct ProfileView: View {
    @State private var user: UserResponse?
    @State private var showLogoutAlert = false
    @State private var showEditGoals = false
    @State private var streak: StreakResponse?
    @State private var myMovies: [MovieResponse] = []
    @State private var meals: [MealResponse] = []

    var watchedCount: Int { myMovies.filter { $0.watched == true }.count }
    var wordsLearned: Int { streak?.learned_words ?? 0 }
    var mealsLogged: Int { meals.count }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: Hero Card
                    ProfileHeroCard(user: user, streak: streak)
                        .padding(.horizontal)

                    // MARK: Progress Overview
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Прогресс").font(.headline)
                            Spacer()
                            Text("всё время").font(.caption).foregroundColor(.secondary)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ProfileStatTile(
                                icon: "film.fill",
                                iconColor: .purple,
                                value: "\(watchedCount)",
                                label: "Фильмов просмотрено",
                                trend: "+3 на этой неделе"
                            )
                            ProfileStatTile(
                                icon: "textformat.abc",
                                iconColor: .blue,
                                value: "\(wordsLearned)",
                                label: "Слов изучено",
                                trend: "streak \(streak?.streak_days ?? 0) дней"
                            )
                            ProfileStatTile(
                                icon: "fork.knife",
                                iconColor: .orange,
                                value: "\(mealsLogged)",
                                label: "Приёмов пищи",
                                trend: "сегодня"
                            )
                            ProfileStatTile(
                                icon: "location.fill",
                                iconColor: .green,
                                value: "12",
                                label: "Маршрутов",
                                trend: "за месяц"
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // MARK: Module Progress
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Модули").font(.headline)

                        ModuleProgressRow(
                            icon: "film.fill",
                            color: .purple,
                            name: "Cinema",
                            subtitle: "\(watchedCount) просмотрено · \(myMovies.filter { $0.watched == false }.count) в watchlist",
                            progress: min(Double(watchedCount) / 20.0, 1.0),
                            level: watchedCount >= 20 ? "Киноман" : watchedCount >= 10 ? "Зритель" : "Новичок"
                        )

                        ModuleProgressRow(
                            icon: "character.book.closed.fill",
                            color: .blue,
                            name: "Languages",
                            subtitle: "\(wordsLearned) слов · \(streak?.streak_days ?? 0) дней подряд",
                            progress: min(Double(wordsLearned) / 100.0, 1.0),
                            level: wordsLearned >= 100 ? "B2" : wordsLearned >= 50 ? "B1" : "A2"
                        )

                        ModuleProgressRow(
                            icon: "fork.knife",
                            color: .orange,
                            name: "Food",
                            subtitle: "\(mealsLogged) приёмов сегодня",
                            progress: min(Double(mealsLogged) / 3.0, 1.0),
                            level: mealsLogged >= 3 ? "На треке" : "Начато"
                        )

                        ModuleProgressRow(
                            icon: "location.fill",
                            color: .green,
                            name: "Logistics",
                            subtitle: "12 маршрутов построено",
                            progress: 0.6,
                            level: "Активный"
                        )
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // MARK: Goals
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Мои цели").font(.headline)
                            Spacer()
                            Button {
                                showEditGoals = true
                            } label: {
                                Text("Изменить")
                                    .font(.caption).foregroundColor(.blue)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(20)
                            }
                        }

                        GoalRow(icon: "flame.fill", color: .orange, title: "Калории в день", value: "\(user?.calorie_goal ?? 2200) ккал")
                        GoalRow(icon: "film.stack", color: .purple, title: "Фильмов в месяц", value: "8 фильмов")
                        GoalRow(icon: "textformat.abc", color: .blue, title: "Слов в день", value: "10 слов")
                        GoalRow(icon: "figure.walk", color: .green, title: "Шагов в день", value: "10,000 шагов")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // MARK: Settings
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Настройки")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.bottom, 12)

                        SettingsRow(icon: "bell.fill", iconColor: .red, title: "Уведомления", subtitle: "Включены")
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "moon.fill", iconColor: .indigo, title: "Тёмная тема", subtitle: "Системная")
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "globe", iconColor: .blue, title: "Язык приложения", subtitle: "Русский")
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "heart.fill", iconColor: .pink, title: "Apple Health", subtitle: "Подключено")
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "lock.fill", iconColor: .gray, title: "Конфиденциальность", subtitle: nil)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)

                    // MARK: Sign Out
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.08))
                        .foregroundColor(.red)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)

                    Text("AURA v1.0 · Made with ❤️")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Выйти?", isPresented: $showLogoutAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Выйти", role: .destructive) {
                    AuthStorage.shared.logout()
                    NotificationCenter.default.post(name: .didLogout, object: nil)
                }
            }
        }
        .task {
            async let u = NetworkManager.shared.getMe()
            async let s: StreakResponse? = try? await NetworkManager.shared.request("/languages/streak")
            async let m = NetworkManager.shared.getMyMovies()
            async let meals = NetworkManager.shared.getMealHistory()
            user = try? await u
            streak = await s
            myMovies = (try? await m) ?? []
            self.meals = (try? await meals) ?? []
        }
    }
}

// MARK: - Profile Hero Card
struct ProfileHeroCard: View {
    let user: UserResponse?
    let streak: StreakResponse?

    var initials: String {
        guard let name = user?.full_name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red:0.2,green:0.5,blue:1.0), Color(red:0.5,green:0.2,blue:1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                    Text(initials)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text(user?.full_name ?? "Пользователь")
                        .font(.title3).bold()
                    Text(user?.email ?? "")
                        .font(.subheadline).foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(streak?.streak_days ?? 0) дней подряд")
                            .font(.caption).bold()
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
                }

                Spacer()
            }

            // Level badge
            HStack(spacing: 12) {
                LevelBadge(emoji: "🎬", label: "Cinema", level: "Зритель", color: .purple)
                LevelBadge(emoji: "📚", label: "Languages", level: "B1", color: .blue)
                LevelBadge(emoji: "🥗", label: "Food", level: "Трекер", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct LevelBadge: View {
    let emoji: String
    let label: String
    let level: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title3)
            Text(level)
                .font(.caption2).bold()
                .foregroundColor(color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(color.opacity(0.1))
                .cornerRadius(6)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Tile
struct ProfileStatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let trend: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.subheadline)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text(trend)
                .font(.caption2)
                .foregroundColor(iconColor)
        }
        .padding(14)
        .background(iconColor.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - Module Progress Row
struct ModuleProgressRow: View {
    let icon: String
    let color: Color
    let name: String
    let subtitle: String
    let progress: Double
    let level: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(name).font(.subheadline).bold()
                        Spacer()
                        Text(level)
                            .font(.caption2).bold()
                            .foregroundColor(color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(color.opacity(0.1))
                            .cornerRadius(20)
                    }
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(color)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
    }
}

// MARK: - Goal Row
struct GoalRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.caption)
            }

            Text(title).font(.subheadline)
            Spacer()

            if let subtitle = subtitle {
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
