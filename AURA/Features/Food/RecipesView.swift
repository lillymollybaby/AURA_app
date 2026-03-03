import SwiftUI

// MARK: - Recipe Model
struct Recipe: Identifiable {
    let id = UUID()
    let name: String
    let image: String // SF Symbol
    let calories: Int
    let cookTime: Int // minutes
    let category: RecipeCategory
    let cuisine: String
    let ingredients: [RecipeIngredient]
    let isSaved: Bool

    var availableCount: Int {
        ingredients.filter { $0.inFridge }.count
    }

    var missingCount: Int {
        ingredients.filter { !$0.inFridge }.count
    }

    var isFullyAvailable: Bool { missingCount == 0 }
}

struct RecipeIngredient: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let inFridge: Bool
}

enum RecipeCategory: String, CaseIterable {
    case breakfast = "Завтрак"
    case lunch = "Обед"
    case dinner = "Ужин"
    case snack = "Снеки"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "cup.and.saucer.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch:     return .yellow
        case .dinner:    return .indigo
        case .snack:     return .mint
        }
    }
}

// MARK: - Recipes View
struct RecipesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Bar
                tabBar

                TabView(selection: $selectedTab) {
                    FromFridgeTab().tag(0)
                    ExploreTab().tag(1)
                    MyRecipesTab().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Рецепты")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            RecipeTabButton(title: "Из холодильника", icon: "refrigerator.fill", isSelected: selectedTab == 0) { selectedTab = 0 }
            RecipeTabButton(title: "Explore", icon: "safari.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
            RecipeTabButton(title: "Мои", icon: "heart.fill", isSelected: selectedTab == 2) { selectedTab = 2 }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Tab Button
struct RecipeTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption2)
                Text(title).font(.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - From Fridge Tab
struct FromFridgeTab: View {
    let recipes = Recipe.fromFridgeMock

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 40, height: 40)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI подобрал рецепты")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("На основе продуктов в вашем холодильнике")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )

                ForEach(recipes) { recipe in
                    FridgeRecipeCard(recipe: recipe)
                }
            }
            .padding()
        }
    }
}

// MARK: - Fridge Recipe Card
struct FridgeRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 14) {
                // Recipe icon
                Image(systemName: recipe.image)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(recipe.category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label("\(recipe.calories) ккал", systemImage: "flame.fill")
                            .font(.caption).foregroundStyle(.orange)
                        Label("\(recipe.cookTime) мин", systemImage: "clock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()

                // Availability badge
                if recipe.isFullyAvailable {
                    Text("Всё есть ✅")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else {
                    Text("Не хватает \(recipe.missingCount)")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            // Ingredients preview
            FlowLayout(spacing: 6) {
                ForEach(recipe.ingredients) { ing in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ing.inFridge ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text(ing.name)
                            .font(.caption2)
                            .foregroundStyle(ing.inFridge ? .primary : .secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        ing.inFridge
                        ? Color.green.opacity(0.08)
                        : Color(.systemGray6)
                    )
                    .clipShape(Capsule())
                }
            }

            // Action Button
            Button {
                // Cook action
            } label: {
                HStack {
                    Image(systemName: "frying.pan.fill")
                    Text("Приготовить")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(recipe.isFullyAvailable ? Color.green : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }
}

// MARK: - Explore Tab
struct ExploreTab: View {
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var searchText = ""
    let recipes = Recipe.exploreMock

    var filteredRecipes: [Recipe] {
        var result = recipes
        if let cat = selectedCategory { result = result.filter { $0.category == cat } }
        if !searchText.isEmpty { result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Поиск рецептов...", text: $searchText)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.title3)
                                        .foregroundStyle(selectedCategory == cat ? .white : cat.color)
                                        .frame(width: 48, height: 48)
                                        .background(selectedCategory == cat ? cat.color : cat.color.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(cat.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(selectedCategory == cat ? cat.color : .secondary)
                                        .fontWeight(selectedCategory == cat ? .bold : .regular)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Recipe Cards
                ForEach(filteredRecipes) { recipe in
                    ExploreRecipeCard(recipe: recipe)
                }
            }
            .padding()
        }
    }
}

// MARK: - Explore Recipe Card
struct ExploreRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: recipe.image)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(recipe.category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name).font(.subheadline).fontWeight(.semibold)
                    HStack(spacing: 10) {
                        Label("\(recipe.calories) ккал", systemImage: "flame.fill")
                            .font(.caption2).foregroundStyle(.orange)
                        Label("\(recipe.cookTime) мин", systemImage: "clock.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(recipe.cuisine)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }

            // Ingredients
            VStack(spacing: 6) {
                ForEach(recipe.ingredients) { ing in
                    HStack(spacing: 10) {
                        Image(systemName: ing.inFridge ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(ing.inFridge ? .green : .gray.opacity(0.4))
                        Text(ing.name)
                            .font(.caption)
                            .foregroundStyle(ing.inFridge ? .primary : .secondary)
                        Spacer()
                        Text(ing.amount)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !ing.inFridge {
                            Button {
                                // add to shopping list
                            } label: {
                                Image(systemName: "cart.badge.plus")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Actions
            if recipe.missingCount > 0 {
                Button {
                    // add all missing to shopping list
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill.badge.plus")
                        Text("Добавить \(recipe.missingCount) в список покупок")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - My Recipes Tab
struct MyRecipesTab: View {
    let saved = Recipe.savedMock

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if saved.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 48)).foregroundStyle(.tertiary)
                        Text("Нет сохранённых рецептов")
                            .font(.headline).foregroundStyle(.secondary)
                        Text("Сохраняйте рецепты из Explore\nили добавьте свои")
                            .font(.subheadline).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(60)
                } else {
                    ForEach(saved) { recipe in
                        SavedRecipeCard(recipe: recipe)
                    }
                }

                // Add Custom Recipe Button
                Button {
                    // add own recipe
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Добавить свой рецепт")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("С фото и ингредиентами")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}

// MARK: - Saved Recipe Card
struct SavedRecipeCard: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: recipe.image)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(recipe.category.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name).font(.subheadline).fontWeight(.medium)
                HStack(spacing: 8) {
                    Label("\(recipe.calories) ккал", systemImage: "flame.fill")
                        .font(.caption2).foregroundStyle(.orange)
                    Label("\(recipe.cookTime) мин", systemImage: "clock.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }
        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}

// MARK: - Mock Data
extension Recipe {
    static var fromFridgeMock: [Recipe] {
        [
            Recipe(name: "Омлет со шпинатом и сыром", image: "frying.pan.fill", calories: 320, cookTime: 15, category: .breakfast, cuisine: "Европейская", ingredients: [
                .init(name: "Яйца", amount: "3 шт", inFridge: true),
                .init(name: "Шпинат", amount: "100г", inFridge: true),
                .init(name: "Сыр Маасдам", amount: "50г", inFridge: true),
                .init(name: "Молоко", amount: "50мл", inFridge: true),
            ], isSaved: false),
            Recipe(name: "Куриный стир-фрай с брокколи", image: "flame.fill", calories: 410, cookTime: 25, category: .lunch, cuisine: "Азиатская", ingredients: [
                .init(name: "Куриная грудка", amount: "200г", inFridge: true),
                .init(name: "Брокколи", amount: "150г", inFridge: true),
                .init(name: "Рис басмати", amount: "100г", inFridge: true),
                .init(name: "Соевый соус", amount: "2 ст.л.", inFridge: false),
            ], isSaved: false),
            Recipe(name: "Салат с помидорами и огурцами", image: "leaf.fill", calories: 180, cookTime: 10, category: .snack, cuisine: "Русская", ingredients: [
                .init(name: "Помидоры", amount: "2 шт", inFridge: true),
                .init(name: "Огурцы", amount: "2 шт", inFridge: true),
                .init(name: "Оливковое масло", amount: "1 ст.л.", inFridge: true),
            ], isSaved: false),
        ]
    }

    static var exploreMock: [Recipe] {
        [
            Recipe(name: "Паста Карбонара", image: "fork.knife", calories: 520, cookTime: 30, category: .dinner, cuisine: "Итальянская", ingredients: [
                .init(name: "Спагетти", amount: "200г", inFridge: false),
                .init(name: "Яйца", amount: "2 шт", inFridge: true),
                .init(name: "Сыр Пармезан", amount: "80г", inFridge: false),
                .init(name: "Бекон", amount: "150г", inFridge: false),
            ], isSaved: false),
            Recipe(name: "Греческий салат", image: "leaf.fill", calories: 250, cookTime: 15, category: .lunch, cuisine: "Греческая", ingredients: [
                .init(name: "Помидоры", amount: "2 шт", inFridge: true),
                .init(name: "Огурцы", amount: "1 шт", inFridge: true),
                .init(name: "Фета", amount: "100г", inFridge: false),
                .init(name: "Оливки", amount: "50г", inFridge: false),
                .init(name: "Оливковое масло", amount: "2 ст.л.", inFridge: true),
            ], isSaved: false),
            Recipe(name: "Овсяная каша с бананом", image: "cup.and.saucer.fill", calories: 350, cookTime: 10, category: .breakfast, cuisine: "Мировая", ingredients: [
                .init(name: "Овсяные хлопья", amount: "80г", inFridge: false),
                .init(name: "Молоко", amount: "200мл", inFridge: true),
                .init(name: "Банан", amount: "1 шт", inFridge: true),
            ], isSaved: false),
        ]
    }

    static var savedMock: [Recipe] {
        [
            Recipe(name: "Омлет со шпинатом и сыром", image: "frying.pan.fill", calories: 320, cookTime: 15, category: .breakfast, cuisine: "Европейская", ingredients: [], isSaved: true),
            Recipe(name: "Салат с помидорами", image: "leaf.fill", calories: 180, cookTime: 10, category: .snack, cuisine: "Русская", ingredients: [], isSaved: true),
        ]
    }
}
