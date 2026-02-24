import SwiftUI
import PhotosUI

// MARK: - FOOD VIEW
struct FoodView: View {
    @State private var summary: DailySummaryResponse?
    @State private var meals: [MealResponse] = []
    @State private var showAddSheet = false
    @State private var dinnerIdeas: String?
    @State private var isLoadingIdeas = false
    @State private var showDinnerIdeas = false

    var progress: Double {
        guard let s = summary, s.calorie_goal > 0 else { return 0 }
        return min(s.total_calories / Double(s.calorie_goal), 1.0)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Hero Calorie Card
                    CalorieHeroCard(summary: summary, progress: progress)
                        .padding(.horizontal)

                    // MARK: Macro Bars
                    MacroGridCard(summary: summary)
                        .padding(.horizontal)

                    // MARK: AI Advice
                    if let advice = summary?.ai_advice, !advice.isEmpty {
                        AIAdviceBanner(text: advice)
                            .padding(.horizontal)
                    }

                    // MARK: Add Food Buttons
                    HStack(spacing: 12) {
                        // Photo button
                        Button {
                            showAddSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Сфотографировать")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red:0.2,green:0.5,blue:1.0), Color(red:0.4,green:0.3,blue:1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }

                        // Manual button
                        NavigationLink(destination: ManualAddFoodView(onAdd: { _ in
                            Task { await refreshData() }
                        })) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Вручную")
                                    .font(.subheadline).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)

                    // MARK: Today's Meals
                    TodayMealsCard(meals: meals, onDelete: { id in
                        Task {
                            try? await NetworkManager.shared.deleteMeal(id: id)
                            await refreshData()
                        }
                    })
                    .padding(.horizontal)

                    // MARK: Dinner Ideas
                    DinnerIdeasCard(
                        ideas: dinnerIdeas,
                        isLoading: isLoadingIdeas,
                        isExpanded: $showDinnerIdeas,
                        onLoad: {
                            isLoadingIdeas = true
                            Task {
                                if let result = try? await NetworkManager.shared.getDinnerIdeas() {
                                    dinnerIdeas = result.ideas
                                }
                                isLoadingIdeas = false
                            }
                        }
                    )
                    .padding(.horizontal)

                    // MARK: Health Sync
                    HealthSyncCard()
                        .padding(.horizontal)

                    Spacer(minLength: 30)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            Task { await refreshData() }
        }) {
            PhotoFoodSheet()
        }
        .task { await refreshData() }
    }

    func refreshData() async {
        async let s = NetworkManager.shared.getTodaySummary()
        async let m = NetworkManager.shared.getMealHistory()
        summary = try? await s
        meals = (try? await m) ?? []
    }
}

// MARK: - Calorie Hero Card
struct CalorieHeroCard: View {
    let summary: DailySummaryResponse?
    let progress: Double

    var calGoal: Int { summary?.calorie_goal ?? 2200 }
    var calEaten: Int { Int(summary?.total_calories ?? 0) }
    var calLeft: Int { max(0, calGoal - calEaten) }

    var ringColor: Color {
        if progress > 0.9 { return .orange }
        if progress > 0.7 { return .blue }
        return .green
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [ringColor.opacity(0.6), ringColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8), value: progress)

                    VStack(spacing: 1) {
                        Text("\(calEaten)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("ккал")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Stats
                VStack(alignment: .leading, spacing: 10) {
                    CalStatRow(icon: "target", color: .blue, label: "Цель", value: "\(calGoal) ккал")
                    CalStatRow(icon: "flame.fill", color: .orange, label: "Съедено", value: "\(calEaten) ккал")
                    CalStatRow(icon: "minus.circle.fill", color: calLeft == 0 ? .red : .green, label: "Осталось", value: "\(calLeft) ккал")
                }

                Spacer()
            }

            // Visual progress bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [ringColor.opacity(0.7), ringColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                            .animation(.spring(response: 0.8), value: progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("0").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%").font(.caption2).bold().foregroundColor(ringColor)
                    Spacer()
                    Text("\(calGoal)").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct CalStatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Macro Grid Card
struct MacroGridCard: View {
    let summary: DailySummaryResponse?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Макронутриенты").font(.headline)
                Spacer()
                Text("сегодня").font(.caption).foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                MacroCircle(
                    value: Int(summary?.total_proteins ?? 0),
                    goal: 120,
                    label: "Белки",
                    unit: "г",
                    color: .blue
                )
                MacroCircle(
                    value: Int(summary?.total_carbs ?? 0),
                    goal: 250,
                    label: "Углеводы",
                    unit: "г",
                    color: .orange
                )
                MacroCircle(
                    value: Int(summary?.total_fats ?? 0),
                    goal: 70,
                    label: "Жиры",
                    unit: "г",
                    color: .purple
                )

                // Вода (статик)
                MacroCircle(
                    value: 6,
                    goal: 8,
                    label: "Вода",
                    unit: "ст",
                    color: .cyan
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct MacroCircle: View {
    let value: Int
    let goal: Int
    let label: String
    let unit: String
    let color: Color

    var progress: Double { goal > 0 ? min(Double(value) / Double(goal), 1.0) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(value)").font(.system(size: 13, weight: .bold))
                    Text(unit).font(.system(size: 8)).foregroundColor(.secondary)
                }
            }
            Text(label).font(.caption2).foregroundColor(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - AI Advice Banner
struct AIAdviceBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.06), Color.purple.opacity(0.06)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Today Meals Card
struct TodayMealsCard: View {
    let meals: [MealResponse]
    let onDelete: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "fork.knife").foregroundColor(.secondary)
                Text("Сегодня").font(.headline)
                Spacer()
                Text("\(meals.count) приёмов").font(.caption).foregroundColor(.secondary)
            }

            if meals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.title2).foregroundColor(.secondary.opacity(0.4))
                    Text("Ничего не добавлено").font(.subheadline).foregroundColor(.secondary)
                    Text("Сфотографируй еду или добавь вручную").font(.caption).foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(Array(meals.enumerated()), id: \.element.id) { idx, meal in
                    if idx > 0 { Divider() }
                    FoodMealRow(meal: meal, onDelete: { onDelete(meal.id) })
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct FoodMealRow: View {
    let meal: MealResponse
    let onDelete: () -> Void
    @State private var showDelete = false

    var mealIcon: String {
        switch meal.meal_type {
        case "breakfast": return "🌅"
        case "lunch": return "☀️"
        case "dinner": return "🌙"
        default: return "🍽️"
        }
    }

    var mealColor: Color {
        switch meal.meal_type {
        case "breakfast": return .orange
        case "lunch": return .yellow
        case "dinner": return .indigo
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(mealColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(mealIcon).font(.title3)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(Int(meal.calories)) ккал")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("Б \(Int(meal.proteins))г")
                        .font(.caption).foregroundColor(.blue)
                    Text("У \(Int(meal.carbs))г")
                        .font(.caption).foregroundColor(.orange)
                    Text("Ж \(Int(meal.fats))г")
                        .font(.caption).foregroundColor(.purple)
                }
                if let tip = meal.ai_analysis, !tip.isEmpty {
                    Text("✨ \(tip)").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }

            Spacer()

            // Delete
            Button {
                withAnimation { showDelete.toggle() }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.6))
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
            }
            .onTapGesture { onDelete() }
        }
    }
}

// MARK: - Dinner Ideas Card
struct DinnerIdeasCard: View {
    let ideas: String?
    let isLoading: Bool
    @Binding var isExpanded: Bool
    let onLoad: () -> Void

    let staticIdeas = [
        ("🐟", "Лосось с киноа", "Мало белка сегодня", "520 ккал"),
        ("🍠", "Батат с овощами", "Сложные углеводы", "380 ккал"),
        ("🥑", "Авокадо тост", "Полезные жиры", "310 ккал"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill").foregroundColor(.indigo)
                    Text("Идеи для ужина").font(.headline)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                    if ideas == nil && !isLoading { onLoad() }
                } label: {
                    HStack(spacing: 4) {
                        if isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text(isExpanded ? "Скрыть" : "AI совет")
                                .font(.caption).foregroundColor(.indigo)
                            Image(systemName: isExpanded ? "chevron.up" : "sparkles")
                                .font(.caption).foregroundColor(.indigo)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(20)
                }
            }

            if isExpanded, let ideas = ideas {
                Text(ideas)
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding()
                    .background(Color.indigo.opacity(0.05))
                    .cornerRadius(12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                ForEach(staticIdeas, id: \.0) { idea in
                    HStack(spacing: 12) {
                        Text(idea.0).font(.title2).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idea.1).font(.subheadline).fontWeight(.semibold)
                            Text(idea.2).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(idea.3).font(.caption).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Health Sync Card

// MARK: - Photo Food Sheet
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
