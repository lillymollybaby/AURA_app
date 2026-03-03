import SwiftUI

// MARK: - Models
struct FridgeItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: String
    let category: FridgeCategory
    let expiryDate: Date
    let emoji: String

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: .now, to: expiryDate).day ?? 0
    }

    var freshness: Freshness {
        if daysUntilExpiry < 0 { return .expired }
        if daysUntilExpiry <= 1 { return .critical }
        if daysUntilExpiry <= 3 { return .warning }
        return .fresh
    }
}

enum Freshness {
    case fresh, warning, critical, expired

    var color: Color {
        switch self {
        case .fresh:    return .green
        case .warning:  return .orange
        case .critical: return .red
        case .expired:  return .gray
        }
    }

    var label: String {
        switch self {
        case .fresh:    return "Свежий"
        case .warning:  return "Скоро"
        case .critical: return "Срочно"
        case .expired:  return "Просрочен"
        }
    }

    var icon: String {
        switch self {
        case .fresh:    return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "flame.fill"
        case .expired:  return "xmark.circle.fill"
        }
    }
}

enum FridgeCategory: String, CaseIterable {
    case meat = "Мясо"
    case dairy = "Молочные"
    case vegetables = "Овощи"
    case fruits = "Фрукты"
    case grains = "Крупы"
    case other = "Другое"

    var icon: String {
        switch self {
        case .meat:       return "🥩"
        case .dairy:      return "🥛"
        case .vegetables: return "🥬"
        case .fruits:     return "🍎"
        case .grains:     return "🌾"
        case .other:      return "📦"
        }
    }

    var color: Color {
        switch self {
        case .meat:       return .red
        case .dairy:      return .blue
        case .vegetables: return .green
        case .fruits:     return .orange
        case .grains:     return .brown
        case .other:      return .gray
        }
    }
}

// MARK: - Fridge View
struct FridgeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var items: [FridgeItem] = FridgeItem.mockData
    @State private var selectedCategory: FridgeCategory? = nil
    @State private var showAddSheet = false
    @State private var searchText = ""

    var filteredItems: [FridgeItem] {
        var result = items
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var groupedItems: [(FridgeCategory, [FridgeItem])] {
        let grouped = Dictionary(grouping: filteredItems, by: { $0.category })
        return FridgeCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items.sorted { $0.daysUntilExpiry < $1.daysUntilExpiry })
        }
    }

    // Expiring soon count
    var expiringCount: Int {
        items.filter { $0.freshness == .critical || $0.freshness == .warning }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Expiry Alert Banner
                    if expiringCount > 0 {
                        expiryBanner
                    }

                    // MARK: - Category Filter
                    categoryFilter

                    // MARK: - Stats Row
                    statsRow

                    // MARK: - Products
                    ForEach(groupedItems, id: \.0) { category, categoryItems in
                        categorySection(category: category, items: categoryItems)
                    }

                    if groupedItems.isEmpty {
                        emptyState
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Холодильник")
            .searchable(text: $searchText, prompt: "Найти продукт...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
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
                AddFridgeItemSheet()
            }
        }
    }

    // MARK: - Expiry Banner
    private var expiryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(expiringCount) продуктов истекают")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Нажмите чтобы посмотреть рецепты")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [.orange, .red.opacity(0.8)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "Все", icon: "tray.full.fill", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(FridgeCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        title: cat.rawValue,
                        emoji: cat.icon,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatBubble(value: "\(items.count)", label: "Всего", icon: "refrigerator.fill", color: .blue)
            StatBubble(value: "\(items.filter { $0.freshness == .fresh }.count)", label: "Свежие", icon: "checkmark.circle.fill", color: .green)
            StatBubble(value: "\(expiringCount)", label: "Истекают", icon: "clock.badge.exclamationmark.fill", color: .orange)
        }
        .padding(.horizontal)
    }

    // MARK: - Category Section
    private func categorySection(category: FridgeCategory, items: [FridgeItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(category.icon)
                    .font(.title3)
                Text(category.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    FridgeItemCard(item: item)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "refrigerator")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Холодильник пуст")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Добавьте продукты вручную\nили отсканируйте штрихкод")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var emoji: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji = emoji {
                    Text(emoji).font(.caption)
                } else if let icon = icon {
                    Image(systemName: icon).font(.caption2)
                }
                Text(title).font(.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Bubble
struct StatBubble: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Fridge Item Card
struct FridgeItemCard: View {
    let item: FridgeItem

    var expiryText: String {
        let days = item.daysUntilExpiry
        if days < 0 { return "Просрочен \(abs(days)) дн." }
        if days == 0 { return "Истекает сегодня!" }
        if days == 1 { return "Ещё 1 день" }
        return "Ещё \(days) дн."
    }

    var body: some View {
        HStack(spacing: 14) {
            // Emoji
            Text(item.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(item.category.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.quantity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Freshness
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: item.freshness.icon)
                    .font(.caption)
                    .foregroundStyle(item.freshness.color)
                Text(expiryText)
                    .font(.caption2)
                    .foregroundStyle(item.freshness.color)
                    .fontWeight(.medium)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    item.freshness == .critical || item.freshness == .expired
                        ? item.freshness.color.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Add Fridge Item Sheet
struct AddFridgeItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var quantity = ""
    @State private var selectedCategory: FridgeCategory = .other
    @State private var expiryDate = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Scan Button
                    Button {
                        // scan barcode
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Сканировать штрихкод")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("Быстрое добавление по коду")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // Manual Fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Или добавить вручную")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Название").font(.caption).foregroundStyle(.secondary)
                            TextField("Например: Куриная грудка", text: $name)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Количество").font(.caption).foregroundStyle(.secondary)
                            TextField("Например: 500г", text: $quantity)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категория").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(FridgeCategory.allCases, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(cat.icon)
                                            Text(cat.rawValue).font(.caption).fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedCategory == cat ? cat.color.opacity(0.15) : Color(.systemGray6))
                                        .foregroundStyle(selectedCategory == cat ? cat.color : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Срок годности").font(.caption).foregroundStyle(.secondary)
                            DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
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
extension FridgeItem {
    static var mockData: [FridgeItem] {
        [
            FridgeItem(name: "Куриная грудка", quantity: "500г", category: .meat, expiryDate: Date().addingTimeInterval(2 * 86400), emoji: "🍗"),
            FridgeItem(name: "Говяжий фарш", quantity: "400г", category: .meat, expiryDate: Date().addingTimeInterval(1 * 86400), emoji: "🥩"),
            FridgeItem(name: "Молоко 3.2%", quantity: "1л", category: .dairy, expiryDate: Date().addingTimeInterval(4 * 86400), emoji: "🥛"),
            FridgeItem(name: "Яйца", quantity: "10 шт", category: .dairy, expiryDate: Date().addingTimeInterval(8 * 86400), emoji: "🥚"),
            FridgeItem(name: "Сыр Маасдам", quantity: "200г", category: .dairy, expiryDate: Date().addingTimeInterval(12 * 86400), emoji: "🧀"),
            FridgeItem(name: "Греческий йогурт", quantity: "250г", category: .dairy, expiryDate: Date().addingTimeInterval(3 * 86400), emoji: "🫙"),
            FridgeItem(name: "Помидоры", quantity: "6 шт", category: .vegetables, expiryDate: Date().addingTimeInterval(5 * 86400), emoji: "🍅"),
            FridgeItem(name: "Огурцы", quantity: "4 шт", category: .vegetables, expiryDate: Date().addingTimeInterval(3 * 86400), emoji: "🥒"),
            FridgeItem(name: "Брокколи", quantity: "300г", category: .vegetables, expiryDate: Date().addingTimeInterval(4 * 86400), emoji: "🥦"),
            FridgeItem(name: "Шпинат", quantity: "150г", category: .vegetables, expiryDate: Date().addingTimeInterval(1 * 86400), emoji: "🥬"),
            FridgeItem(name: "Яблоки", quantity: "5 шт", category: .fruits, expiryDate: Date().addingTimeInterval(10 * 86400), emoji: "🍎"),
            FridgeItem(name: "Бананы", quantity: "3 шт", category: .fruits, expiryDate: Date().addingTimeInterval(2 * 86400), emoji: "🍌"),
            FridgeItem(name: "Рис басмати", quantity: "1кг", category: .grains, expiryDate: Date().addingTimeInterval(180 * 86400), emoji: "🍚"),
            FridgeItem(name: "Гречка", quantity: "800г", category: .grains, expiryDate: Date().addingTimeInterval(200 * 86400), emoji: "🌾"),
            FridgeItem(name: "Оливковое масло", quantity: "500мл", category: .other, expiryDate: Date().addingTimeInterval(90 * 86400), emoji: "🫒"),
        ]
    }
}
