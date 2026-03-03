import SwiftUI
import PhotosUI

struct FoodView: View {
    @State private var summary: DailySummaryResponse?
    @State private var meals: [MealResponse] = []
    @State private var showAddSheet = false
    @State private var showScanSheet = false
    @State private var error: AppError?
    @State private var dinnerIdeas: String?
    @State private var isLoadingIdeas = false
    @State private var showDinnerIdeas = false

    // Приоритет: сервер → ProfileSettings → дефолт 2200
    var effectiveCalorieGoal: Int {
        summary?.calorie_goal ?? ProfileSettings.shared.calorieGoal
    }

    var progress: Double {
        guard let s = summary, effectiveCalorieGoal > 0 else { return 0 }
        return min(s.total_calories / Double(effectiveCalorieGoal), 1.0)
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Calorie Ring
                Section {
                    CalorieRingRow(summary: summary, progress: progress)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // MARK: Macros
                Section {
                    MacroRow(label: "Белки", value: summary?.total_proteins ?? 0, goal: 150, color: .blue, unit: "г")
                    MacroRow(label: "Углеводы", value: summary?.total_carbs ?? 0, goal: 250, color: .orange, unit: "г")
                    MacroRow(label: "Жиры", value: summary?.total_fats ?? 0, goal: 70, color: .pink, unit: "г")
                } header: {
                    Text("Макронутриенты")
                }

                // MARK: Quick Add
                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Сфотографировать еду", systemImage: "camera")
                    }

                    NavigationLink {
                        ManualAddFoodView(onAdd: { _ in Task { await refreshData() } })
                    } label: {
                        Label("Добавить вручную", systemImage: "square.and.pencil")
                    }

                    Button {
                        showScanSheet = true
                    } label: {
                        Label("Сканировать этикетку", systemImage: "barcode.viewfinder")
                    }
                } header: {
                    Text("Добавить")
                }

                // MARK: AI Advice
                if let advice = summary?.ai_advice, !advice.isEmpty {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                                .font(.body)
                            Text(advice)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Совет дня")
                    }
                }

                // MARK: Today's Meals
                if !meals.isEmpty {
                    Section {
                        ForEach(meals) { meal in
                            MealListRow(meal: meal)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                let id = meals[i].id
                                Task {
                                    try? await NetworkManager.shared.deleteMeal(id: id)
                                    await refreshData()
                                }
                            }
                        }
                    } header: {
                        Text("Сегодня")
                    }
                }

                // MARK: Dinner Ideas
                Section {
                    if let ideas = dinnerIdeas {
                        Text(ideas)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            isLoadingIdeas = true
                            Task {
                                if let r = try? await NetworkManager.shared.getDinnerIdeas() {
                                    dinnerIdeas = r.ideas
                                }
                                isLoadingIdeas = false
                            }
                        } label: {
                            if isLoadingIdeas {
                                HStack {
                                    ProgressView().padding(.trailing, 4)
                                    Text("Генерируем...")
                                }
                            } else {
                                Label("Идеи для ужина от AI", systemImage: "wand.and.stars")
                            }
                        }
                        .disabled(isLoadingIdeas)
                    }
                } header: {
                    Text("Ужин")
                }

                // MARK: Health Sync
                Section {
                    HealthSyncCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Apple Health")
                }
            }
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScanSheet = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .errorAlert($error)
            .sheet(isPresented: $showAddSheet, onDismiss: {
                Task { await refreshData() }
            }) {
                PhotoFoodSheet()
            }
            .sheet(isPresented: $showScanSheet) {
                ScanDecideView()
            }
            .task { await refreshData() }
            .refreshable { await refreshData() }
        }
    }

    func refreshData() async {
        do {
            async let s = NetworkManager.shared.getTodaySummary()
            async let m = NetworkManager.shared.getMealHistory()
            summary = try await s
            meals = try await m
        } catch {
            self.error = AppError(error)
        }
    }
}

// MARK: - Calorie Ring Row
struct CalorieRingRow: View {
    let summary: DailySummaryResponse?
    let progress: Double

    var calGoal: Int { summary?.calorie_goal ?? ProfileSettings.shared.calorieGoal }
    var calEaten: Int { Int(summary?.total_calories ?? 0) }
    var calLeft: Int { max(0, calGoal - calEaten) }

    var ringColor: Color {
        if progress > 0.95 { return .orange }
        if progress > 0.75 { return .blue }
        return .green
    }

    var body: some View {
        HStack(spacing: 24) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 12)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: progress)
                VStack(spacing: 1) {
                    Text("\(calEaten)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("ккал")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "target").foregroundStyle(.blue).font(.caption)
                    Text("Цель: \(calGoal) ккал").font(.subheadline)
                }
                HStack {
                    Image(systemName: "checkmark.circle").foregroundStyle(.green).font(.caption)
                    Text("Съедено: \(calEaten) ккал").font(.subheadline)
                }
                HStack {
                    Image(systemName: calLeft == 0 ? "exclamationmark.circle" : "minus.circle")
                        .foregroundStyle(calLeft == 0 ? .orange : .secondary).font(.caption)
                    Text("Осталось: \(calLeft) ккал").font(.subheadline)
                        .foregroundStyle(calLeft == 0 ? .orange : .primary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Macro Row
struct MacroRow: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color
    let unit: String

    var progress: Double { min(value / goal, 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value)) / \(Int(goal)) \(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: progress)
                .tint(color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Meal List Row
struct MealListRow: View {
    let meal: MealResponse

    var mealIcon: String {
        switch meal.meal_type {
        case "breakfast": return "sunrise"
        case "lunch": return "sun.max"
        case "dinner": return "moon.stars"
        default: return "fork.knife"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mealIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let tip = meal.ai_analysis, !tip.isEmpty {
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.calories))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text("ккал")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PhotoFoodSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var analyzedMeal: MealResponse? = nil
    @State private var isAnalyzing = false
    @State private var errorMessage = ""
    @State private var mealType = "snack"
    @State private var savedSuccessfully = false

    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    let mealLabels = ["Завтрак", "Обед", "Ужин", "Перекус"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Meal type picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Тип приёма пищи").font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                Button {
                                    mealType = mealTypes[i]
                                } label: {
                                    Text(mealLabels[i])
                                        .font(.caption).fontWeight(.semibold)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(mealType == mealTypes[i] ? Color.blue : Color(.systemGray6))
                                        .foregroundColor(mealType == mealTypes[i] ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Photo picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(height: 220)

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue.opacity(0.7))
                                    Text("Нажми чтобы выбрать фото")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Gemini AI определит КБЖУ")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                                await analyzePhoto(imageData: data)
                            }
                        }
                    }

                    // Loading
                    if isAnalyzing {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Gemini анализирует фото...")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                    }

                    // Result
                    if let meal = analyzedMeal {
                        AnalyzedMealCard(meal: meal)
                            .padding(.horizontal)

                        if savedSuccessfully {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("Добавлено в дневник!").fontWeight(.semibold).foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }

                    // Error
                    if !errorMessage.isEmpty {
                        Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                    }
                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить еду")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                if savedSuccessfully {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") { dismiss() }
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }

    func analyzePhoto(imageData: Data) async {
        isAnalyzing = true
        errorMessage = ""
        do {
            let meal = try await NetworkManager.shared.analyzeFoodPhoto(imageData: imageData, mealType: mealType)
            analyzedMeal = meal
            savedSuccessfully = true
        } catch {
            errorMessage = "Ошибка анализа: \(error.localizedDescription)"
        }
        isAnalyzing = false
    }
}

struct AnalyzedMealCard: View {
    let meal: MealResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name).font(.title3).bold()
                    if let tip = meal.ai_analysis, !tip.isEmpty {
                        Text(tip).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.calories))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                    Text("ккал").font(.caption).foregroundColor(.secondary)
                }
            }

            Divider()

            HStack(spacing: 0) {
                MacroStat(value: Int(meal.proteins), label: "Белки", unit: "г", color: .blue)
                Divider().frame(height: 40)
                MacroStat(value: Int(meal.carbs), label: "Углеводы", unit: "г", color: .orange)
                Divider().frame(height: 40)
                MacroStat(value: Int(meal.fats), label: "Жиры", unit: "г", color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green.opacity(0.2), lineWidth: 1.5)
        )
    }
}

struct MacroStat: View {
    let value: Int
    let label: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)\(unit)").font(.title3).bold().foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Manual Add Food View
struct ManualAddFoodView: View {
    let onAdd: (MealResponse) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var proteins = ""
    @State private var carbs = ""
    @State private var fats = ""
    @State private var mealType = "snack"
    @State private var isLoading = false
    @State private var errorMessage = ""

    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    let mealLabels = ["🌅 Завтрак", "☀️ Обед", "🌙 Ужин", "🍽️ Перекус"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Meal type
                VStack(alignment: .leading, spacing: 10) {
                    Text("Тип").font(.subheadline).bold().padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                Button {
                                    mealType = mealTypes[i]
                                } label: {
                                    Text(mealLabels[i])
                                        .font(.subheadline).fontWeight(.semibold)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(mealType == mealTypes[i] ? Color.blue : Color(.systemBackground))
                                        .foregroundColor(mealType == mealTypes[i] ? .white : .primary)
                                        .cornerRadius(20)
                                        .shadow(color: .black.opacity(0.05), radius: 4)
                                }
                            }
                        }.padding(.horizontal)
                    }
                }

                // Fields
                VStack(spacing: 12) {
                    ManualField(title: "Название блюда", placeholder: "Например: Греческий салат", text: $name, keyboard: .default)
                    ManualField(title: "Калории (ккал)", placeholder: "0", text: $calories, keyboard: .numberPad)

                    HStack(spacing: 12) {
                        ManualField(title: "Белки (г)", placeholder: "0", text: $proteins, keyboard: .numberPad)
                        ManualField(title: "Углеводы (г)", placeholder: "0", text: $carbs, keyboard: .numberPad)
                        ManualField(title: "Жиры (г)", placeholder: "0", text: $fats, keyboard: .numberPad)
                    }
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                }

                // Add button
                Button {
                    Task { await addMeal() }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        else { Image(systemName: "plus.circle.fill"); Text("Добавить").fontWeight(.bold) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(name.isEmpty ? Color(.systemGray4) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(name.isEmpty || isLoading)
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Добавить вручную")
        .navigationBarTitleDisplayMode(.inline)
    }

    func addMeal() async {
        guard !name.isEmpty else { return }
        isLoading = true
        errorMessage = ""

        struct ManualMeal: Codable {
            let name: String
            let calories: Double
            let proteins: Double
            let fats: Double
            let carbs: Double
            let meal_type: String
        }

        let body = ManualMeal(
            name: name,
            calories: Double(calories) ?? 0,
            proteins: Double(proteins) ?? 0,
            fats: Double(fats) ?? 0,
            carbs: Double(carbs) ?? 0,
            meal_type: mealType
        )

        if let meal: MealResponse = try? await NetworkManager.shared.request("/food/manual", method: "POST", body: body) {
            onAdd(meal)
            dismiss()
        } else {
            errorMessage = "Не удалось добавить блюдо"
        }

        isLoading = false
    }
}

struct ManualField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

struct HealthSyncCard: View {
    @ObservedObject var health = HealthKitManager.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.text.square.fill").foregroundColor(.red)
                Text("Health Sync").font(.headline)
                Spacer()
                if !health.isAuthorized {
                    Button("Подключить") { health.requestAuthorization() }
                        .font(.caption).foregroundColor(.blue)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1)).cornerRadius(20)
                } else {
                    Text("Apple Health ✓").font(.caption2).foregroundColor(.green)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                HealthTile(icon: "figure.walk", iconColor: .red, value: health.steps > 0 ? health.stepsFormatted : "—", label: "Шагов", note: health.stepsGoalNote)
                HealthTile(icon: "flame.fill", iconColor: .orange, value: "\(Int(health.activeCalories))", label: "Акт. ккал", note: health.calorieAdjustment > 0 ? "+\(health.calorieAdjustment) к норме" : "В норме")
                HealthTile(icon: "bed.double.fill", iconColor: .indigo, value: health.sleepHours > 0 ? health.sleepFormatted : "—", label: "Сон", note: health.sleepHours >= 7 ? "Хороший отдых" : "Нет данных")
                HealthTile(icon: "heart.fill", iconColor: .pink, value: health.heartRateFormatted, label: "Пульс", note: "уд/мин")
            }
            if health.isAuthorized {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundColor(.orange)
                    Text(health.healthAdvice).font(.caption).foregroundColor(.secondary)
                }
                .padding(10).background(Color.orange.opacity(0.08)).cornerRadius(10)
            }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .onAppear { if health.isAuthorized { health.fetchAll() } }
    }
}

struct HealthTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundColor(iconColor).font(.subheadline)
            Text(value).font(.title3).fontWeight(.bold)
            Text(label).font(.caption).foregroundColor(.secondary)
            if !note.isEmpty { Text(note).font(.caption2).foregroundColor(.secondary.opacity(0.7)) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(iconColor.opacity(0.06))
        .cornerRadius(14)
    }
}
