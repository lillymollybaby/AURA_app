import SwiftUI
import Combine

class ProfileSettings: ObservableObject {
    static let shared = ProfileSettings()
    @Published var city: String { didSet { UserDefaults.standard.set(city, forKey: "user_city") } }
    @Published var learningLanguage: String { didSet { UserDefaults.standard.set(learningLanguage, forKey: "learning_language") } }
    @Published var letterboxdUsername: String { didSet { UserDefaults.standard.set(letterboxdUsername, forKey: "letterboxd_username") } }
    @Published var calorieGoal: Int { didSet { UserDefaults.standard.set(calorieGoal, forKey: "calorie_goal_local") } }
    @Published var notificationsEnabled: Bool { didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled") } }
    @Published var darkMode: String { didSet { UserDefaults.standard.set(darkMode, forKey: "dark_mode") } }
    @Published var gatheringTime: Int { didSet { UserDefaults.standard.set(gatheringTime, forKey: "gathering_time") } }
    @Published var wordsDailyGoal: Int { didSet { UserDefaults.standard.set(wordsDailyGoal, forKey: "words_daily_goal") } }

    init() {
        city = UserDefaults.standard.string(forKey: "user_city") ?? ""
        learningLanguage = UserDefaults.standard.string(forKey: "learning_language") ?? "German"
        letterboxdUsername = UserDefaults.standard.string(forKey: "letterboxd_username") ?? ""
        let cal = UserDefaults.standard.integer(forKey: "calorie_goal_local")
        calorieGoal = cal == 0 ? 2200 : cal
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        darkMode = UserDefaults.standard.string(forKey: "dark_mode") ?? "Системная"
        let gt = UserDefaults.standard.integer(forKey: "gathering_time")
        gatheringTime = gt == 0 ? 15 : gt
        let wd = UserDefaults.standard.integer(forKey: "words_daily_goal")
        wordsDailyGoal = wd == 0 ? 10 : wd
    }
}

enum ProfileEditSheet: String, Identifiable {
    case city, gathering, letterboxd, calories, words_goal
    var id: String { rawValue }
}

struct ProfileView: View {
    @StateObject private var settings = ProfileSettings.shared
    @State private var user: UserResponse?
    @State private var streak: StreakResponse?
    @State private var myMovies: [MovieResponse] = []
    @State private var meals: [MealResponse] = []
    @State private var showLogoutAlert = false
    @State private var activeSheet: ProfileEditSheet? = nil

    var watchedCount: Int { myMovies.filter { $0.watched == true }.count }
    var wordsLearned: Int { streak?.learned_words ?? 0 }
    var initials: String {
        let name = user?.full_name ?? user?.email ?? "U"
        return String(name.prefix(1)).uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Hero
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.gradient)
                                .frame(width: 60, height: 60)
                            Text(initials)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user?.full_name ?? "Пользователь")
                                .font(.headline)
                            Text(user?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Stats
                Section {
                    HStack(spacing: 0) {
                        StatCell(value: "\(watchedCount)", label: "Фильмов")
                        Divider()
                        StatCell(value: "\(wordsLearned)", label: "Слов")
                        Divider()
                        StatCell(value: "\(meals.count)", label: "Приёмов пищи")
                        Divider()
                        StatCell(value: "\(streak?.streak_days ?? 0)", label: "Дней streak")
                    }
                    .frame(height: 64)
                    .listRowInsets(EdgeInsets())
                }

                // MARK: Logistics
                Section("Logistics") {
                    NavigationLink {
                        EditTextSheet(title: "Мой город", value: settings.city) { settings.city = $0 }
                    } label: {
                        LabeledContent("Город", value: settings.city.isEmpty ? "Не указан" : settings.city)
                    }
                    NavigationLink {
                        EditPickerSheet(title: "Время на сборы", value: settings.gatheringTime, options: [5,10,15,20,30,45,60]) { settings.gatheringTime = $0 }
                    } label: {
                        LabeledContent("Время на сборы", value: "\(settings.gatheringTime) мин")
                    }
                }

                // MARK: Languages
                Section("Languages") {
                    NavigationLink {
                        EditTextSheet(title: "Letterboxd", value: settings.letterboxdUsername) { settings.letterboxdUsername = $0 }
                    } label: {
                        LabeledContent("Letterboxd", value: settings.letterboxdUsername.isEmpty ? "Не подключён" : "@\(settings.letterboxdUsername)")
                    }
                    NavigationLink {
                        EditPickerSheet(title: "Цель слов в день", value: settings.wordsDailyGoal, options: [5,10,15,20,30]) { settings.wordsDailyGoal = $0 }
                    } label: {
                        LabeledContent("Цель слов в день", value: "\(settings.wordsDailyGoal) слов")
                    }
                }

                // MARK: Food
                Section("Food") {
                    NavigationLink {
                        EditPickerSheet(title: "Цель калорий", value: settings.calorieGoal, options: [1500,1800,2000,2200,2500,3000]) { settings.calorieGoal = $0 }
                    } label: {
                        LabeledContent("Цель калорий", value: "\(settings.calorieGoal) ккал")
                    }
                }

                // MARK: App
                Section("Приложение") {
                    Toggle("Уведомления", isOn: $settings.notificationsEnabled)
                    NavigationLink {
                        EditSegmentSheet(title: "Тема", value: settings.darkMode, options: ["Светлая","Тёмная","Системная"]) { settings.darkMode = $0 }
                    } label: {
                        LabeledContent("Тема", value: settings.darkMode)
                    }
                }

                // MARK: Account
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Выйти?", isPresented: $showLogoutAlert) {
                Button("Выйти", role: .destructive) {
                    AuthStorage.shared.logout()
                    NotificationCenter.default.post(name: .didLogout, object: nil)
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Вы будете перенаправлены на экран входа")
            }
            .task {
                if let u = try? await NetworkManager.shared.getMe() { user = u }
                if let s: StreakResponse = try? await NetworkManager.shared.request("/languages/streak") { streak = s }
                if let m = try? await NetworkManager.shared.getMyMovies() { myMovies = m }
                if let ml = try? await NetworkManager.shared.getMealHistory() { meals = ml }
            }
        }
    }
}

// MARK: - Stat Cell
struct StatCell: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Edit Sheets
struct EditTextSheet: View {
    let title: String
    @State private var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss

    init(title: String, value: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self._text = State(initialValue: value)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            TextField(title, text: $text)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { onSave(text); dismiss() }
            }
        }
    }
}

struct EditPickerSheet: View {
    let title: String
    @State private var selected: Int
    let options: [Int]
    let onSave: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    init(title: String, value: Int, options: [Int], onSave: @escaping (Int) -> Void) {
        self.title = title
        self._selected = State(initialValue: value)
        self.options = options
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Picker(title, selection: $selected) {
                ForEach(options, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { onSave(selected); dismiss() }
            }
        }
    }
}

struct EditSegmentSheet: View {
    let title: String
    @State private var selected: String
    let options: [String]
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss

    init(title: String, value: String, options: [String], onSave: @escaping (String) -> Void) {
        self.title = title
        self._selected = State(initialValue: value)
        self.options = options
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Picker(title, selection: $selected) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.inline)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") { onSave(selected); dismiss() }
            }
        }
    }
}
