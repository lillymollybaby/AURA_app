import SwiftUI

// MARK: - Shopping Item Model
struct ShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let category: ShoppingCategory
    var isChecked: Bool
    let fromRecipe: String? // nil = added manually
}

enum ShoppingCategory: String, CaseIterable {
    case vegetables = "Овощи и фрукты"
    case meat = "Мясо и рыба"
    case dairy = "Молочные"
    case grains = "Крупы и хлеб"
    case other = "Другое"

    var icon: String {
        switch self {
        case .vegetables: return "leaf.fill"
        case .meat:       return "fish.fill"
        case .dairy:      return "cup.and.saucer.fill"
        case .grains:     return "birthday.cake.fill"
        case .other:      return "bag.fill"
        }
    }

    var color: Color {
        switch self {
        case .vegetables: return .green
        case .meat:       return .red
        case .dairy:      return .blue
        case .grains:     return .brown
        case .other:      return .gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .vegetables: return 0
        case .meat:       return 1
        case .dairy:      return 2
        case .grains:     return 3
        case .other:      return 4
        }
    }
}

// MARK: - Shopping List View
struct ShoppingListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var items: [ShoppingItem] = ShoppingItem.mockData
    @State private var showAddSheet = false
    @State private var selectedSection = 0

    var needToBuy: [ShoppingItem] {
        items.filter { !$0.isChecked && $0.fromRecipe == nil }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    var fromRecipes: [ShoppingItem] {
        items.filter { !$0.isChecked && $0.fromRecipe != nil }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    var bought: [ShoppingItem] {
        items.filter { $0.isChecked }
    }

    var totalItems: Int { items.filter { !$0.isChecked }.count }
    var checkedItems: Int { items.filter { $0.isChecked }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Progress Header
                    progressHeader

                    // MARK: - Section Picker
                    sectionPicker

                    // MARK: - Content
                    switch selectedSection {
                    case 0:
                        needToBuySection
                    case 1:
                        fromRecipesSection
                    case 2:
                        boughtSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Список покупок")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            // share
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .symbolRenderingMode(.hierarchical)
                        }
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddShoppingItemSheet()
            }
        }
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        let total = items.count
        let done = checkedItems
        let pct = total > 0 ? Double(done) / Double(total) : 0

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(done) из \(total)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                    Text("продуктов куплено")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: pct)
                    Text("\(Int(pct * 100))%")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: max(6, geo.size.width * pct), height: 6)
                        .animation(.spring(response: 0.6), value: pct)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Section Picker
    private var sectionPicker: some View {
        HStack(spacing: 6) {
            SectionTab(title: "Купить", count: needToBuy.count, icon: "cart.fill", isSelected: selectedSection == 0) { selectedSection = 0 }
            SectionTab(title: "Из рецептов", count: fromRecipes.count, icon: "book.fill", isSelected: selectedSection == 1) { selectedSection = 1 }
            SectionTab(title: "Куплено", count: checkedItems, icon: "checkmark.circle.fill", isSelected: selectedSection == 2) { selectedSection = 2 }
        }
        .padding(.horizontal)
    }

    // MARK: - Need to Buy
    private var needToBuySection: some View {
        VStack(spacing: 12) {
            if needToBuy.isEmpty {
                emptySection(icon: "cart", text: "Список пуст", sub: "Добавьте продукты вручную или из рецептов")
            } else {
                let grouped = Dictionary(grouping: needToBuy, by: { $0.category })
                let sortedKeys = grouped.keys.sorted { $0.sortOrder < $1.sortOrder }

                ForEach(sortedKeys, id: \.self) { cat in
                    shoppingCategorySection(category: cat, items: grouped[cat] ?? [])
                }
            }
        }
    }

    // MARK: - From Recipes
    private var fromRecipesSection: some View {
        VStack(spacing: 12) {
            if fromRecipes.isEmpty {
                emptySection(icon: "book.closed", text: "Нет ингредиентов из рецептов", sub: "Добавьте рецепт — недостающие продукты появятся здесь")
            } else {
                // Group by recipe
                let byRecipe = Dictionary(grouping: fromRecipes, by: { $0.fromRecipe ?? "" })
                ForEach(Array(byRecipe.keys.sorted()), id: \.self) { recipeName in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(recipeName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 6) {
                            ForEach(byRecipe[recipeName] ?? []) { item in
                                ShoppingItemRow(item: item, onToggle: { toggleItem(item) })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Bought
    private var boughtSection: some View {
        VStack(spacing: 12) {
            if bought.isEmpty {
                emptySection(icon: "checkmark.circle", text: "Ничего не куплено", sub: "Отмечайте продукты в магазине")
            } else {
                // Move to Fridge Button
                Button {
                    // move all to fridge
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "refrigerator.fill")
                            .font(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Всё в холодильник")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("\(bought.count) продуктов → холодильник")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    ForEach(bought) { item in
                        ShoppingItemRow(item: item, onToggle: { toggleItem(item) })
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Category Section
    private func shoppingCategorySection(category: ShoppingCategory, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 6) {
                ForEach(items) { item in
                    ShoppingItemRow(item: item, onToggle: { toggleItem(item) })
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty Section
    private func emptySection(icon: String, text: String, sub: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36)).foregroundStyle(.tertiary)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
            Text(sub).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toggle
    private func toggleItem(_ item: ShoppingItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isChecked.toggle()
        }
    }
}

// MARK: - Section Tab
struct SectionTab: View {
    let title: String
    let count: Int
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.caption2)
                    Text("\(count)").font(.caption).fontWeight(.bold)
                }
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shopping Item Row
struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? .green : Color(.systemGray3))
                    .animation(.spring(response: 0.3), value: item.isChecked)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    if let recipe = item.fromRecipe {
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill").font(.system(size: 8))
                            Text(recipe).font(.caption2)
                        }
                        .foregroundStyle(.blue.opacity(0.7))
                    }
                }

                Spacer()

                Text(item.amount)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            )
            .opacity(item.isChecked ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Shopping Item Sheet
struct AddShoppingItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCategory: ShoppingCategory = .other

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Название").font(.caption).foregroundStyle(.secondary)
                        TextField("Например: Молоко", text: $name)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Количество").font(.caption).foregroundStyle(.secondary)
                        TextField("Например: 1л", text: $amount)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Отдел").font(.caption).foregroundStyle(.secondary)
                        ForEach(ShoppingCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: cat.icon)
                                        .font(.body)
                                        .foregroundStyle(cat.color)
                                        .frame(width: 32)
                                    Text(cat.rawValue)
                                        .font(.subheadline)
                                    Spacer()
                                    if selectedCategory == cat {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedCategory == cat ? cat.color.opacity(0.08) : Color(.systemGray6))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Добавить")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.isEmpty ? Color(.systemGray4) : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(name.isEmpty)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mock Data
extension ShoppingItem {
    static var mockData: [ShoppingItem] {
        [
            // Manual items
            ShoppingItem(name: "Хлеб цельнозерновой", amount: "1 шт", category: .grains, isChecked: false, fromRecipe: nil),
            ShoppingItem(name: "Авокадо", amount: "2 шт", category: .vegetables, isChecked: false, fromRecipe: nil),
            ShoppingItem(name: "Творог 5%", amount: "400г", category: .dairy, isChecked: false, fromRecipe: nil),
            ShoppingItem(name: "Лосось филе", amount: "300г", category: .meat, isChecked: false, fromRecipe: nil),
            ShoppingItem(name: "Лимон", amount: "2 шт", category: .vegetables, isChecked: false, fromRecipe: nil),

            // From recipes
            ShoppingItem(name: "Спагетти", amount: "200г", category: .grains, isChecked: false, fromRecipe: "Паста Карбонара"),
            ShoppingItem(name: "Бекон", amount: "150г", category: .meat, isChecked: false, fromRecipe: "Паста Карбонара"),
            ShoppingItem(name: "Пармезан", amount: "80г", category: .dairy, isChecked: false, fromRecipe: "Паста Карбонара"),
            ShoppingItem(name: "Фета", amount: "100г", category: .dairy, isChecked: false, fromRecipe: "Греческий салат"),
            ShoppingItem(name: "Оливки", amount: "50г", category: .other, isChecked: false, fromRecipe: "Греческий салат"),

            // Already bought
            ShoppingItem(name: "Яблоки", amount: "1кг", category: .vegetables, isChecked: true, fromRecipe: nil),
            ShoppingItem(name: "Кефир", amount: "1л", category: .dairy, isChecked: true, fromRecipe: nil),
        ]
    }
}
