import SwiftUI
import Combine
import CoreLocation

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var cityName: String = ""

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc
        // Reverse geocode for city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async { self?.cityName = city }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Models
struct LogisticsTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var subtitle: String
    var address: String
    var time: String
    var date: Date
    var driveMinutes: Int
    var parkMinutes: Int
    var icon: String
    var iconColor: String
    var status: TaskStatus
    var alert: String?
    var isErrand: Bool
    var placeLat: Double?
    var placeLon: Double?

    enum TaskStatus: String, Codable {
        case onTime, leaveNow, delayed, done
    }

    var iconColorValue: Color {
        switch iconColor {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        default: return .gray
        }
    }
}

struct RichPlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let category: String
    let rating: Double?
    let workingHours: String?
    let phone: String?
    let lat: Double
    let lon: Double
    let distanceMeters: Int?

    // Map from 2GIS PlaceResult
    init(from place: PlaceResult, userLocation: CLLocation?) {
        self.name = place.name
        self.address = place.address ?? ""
        self.category = place.type ?? "Место"
        self.rating = nil
        self.workingHours = nil
        self.phone = nil
        self.lat = place.lat ?? 0
        self.lon = place.lon ?? 0
        if let userLoc = userLocation, let lat = place.lat, let lon = place.lon {
            let placeLoc = CLLocation(latitude: lat, longitude: lon)
            self.distanceMeters = Int(userLoc.distance(from: placeLoc))
        } else {
            self.distanceMeters = nil
        }
    }

    var categoryIcon: String {
        let c = category.lowercased()
        if c.contains("стоматол") || c.contains("клиник") || c.contains("медиц") || c.contains("больниц") { return "cross.fill" }
        if c.contains("аптек") { return "pills.fill" }
        if c.contains("банк") || c.contains("банкомат") { return "building.columns.fill" }
        if c.contains("магазин") || c.contains("супермаркет") || c.contains("продукт") { return "cart.fill" }
        if c.contains("парикмахер") || c.contains("барбер") || c.contains("салон") { return "scissors" }
        if c.contains("ресторан") || c.contains("кафе") || c.contains("еда") { return "fork.knife" }
        if c.contains("спорт") || c.contains("фитнес") || c.contains("йога") { return "figure.run" }
        if c.contains("офис") || c.contains("бизнес") { return "briefcase.fill" }
        return "mappin.circle.fill"
    }

    var categoryColor: Color {
        let c = category.lowercased()
        if c.contains("стоматол") || c.contains("клиник") || c.contains("медиц") { return .red }
        if c.contains("аптек") { return .green }
        if c.contains("банк") { return .blue }
        if c.contains("магазин") || c.contains("продукт") { return .purple }
        if c.contains("парикмахер") || c.contains("барбер") { return .orange }
        if c.contains("ресторан") || c.contains("кафе") { return .pink }
        return .gray
    }

    var distanceText: String {
        guard let d = distanceMeters else { return "" }
        if d < 1000 { return "\(d) м" }
        return String(format: "%.1f км", Double(d) / 1000)
    }
}

struct TrafficRoad: Identifiable {
    let id = UUID()
    let name: String
    let level: Double
    var color: Color {
        if level < 0.3 { return .green }
        if level < 0.6 { return .yellow }
        if level < 0.8 { return .orange }
        return .red
    }
}

// MARK: - Persistence
class LogisticsPersistence {
    static let key = "saved_logistics_tasks"

    static func save(_ tasks: [LogisticsTask]) {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [LogisticsTask] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tasks = try? JSONDecoder().decode([LogisticsTask].self, from: data) else { return [] }
        return tasks
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - ViewModel
@MainActor
class LogisticsViewModel: ObservableObject {
    @Published var tasks: [LogisticsTask] = []
    @Published var roads: [TrafficRoad] = [
        TrafficRoad(name: "I-90 West", level: 0.2),
        TrafficRoad(name: "Main Street", level: 0.85),
        TrafficRoad(name: "Oak Avenue", level: 0.55),
        TrafficRoad(name: "Highway 101", level: 0.15),
        TrafficRoad(name: "Elm Street", level: 0.4),
    ]
    @Published var showAddTask = false
    @Published var isParsingTask = false
    @Published var showSavePrompt = false
    @Published var lastAddedTask: LogisticsTask?

    var urgentTask: LogisticsTask? { tasks.first { $0.status == .leaveNow } }
    var totalDriveMinutes: Int { tasks.map { $0.driveMinutes }.reduce(0, +) }

    init() {
        // Load saved tasks if any
        let saved = LogisticsPersistence.load()
        if !saved.isEmpty {
            tasks = saved
        }
    }

    func parseAndAddTask(input: String, selectedPlace: RichPlaceResult?) async {
        isParsingTask = true
        defer { isParsingTask = false }

        let parsed: [String: String]? = try? await NetworkManager.shared.request(
            "/logistics/parse-task", method: "POST", body: ["text": input]
        )

        let cal = Calendar.current
        var taskDate = Date()
        var hour = 12, minute = 0

        if let timeStr = parsed?["time"] {
            let parts = timeStr.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 { hour = parts[0]; minute = parts[1] }
        }
        if let offsetStr = parsed?["date_offset_days"], let offset = Int(offsetStr), offset > 0 {
            taskDate = cal.date(byAdding: .day, value: offset, to: taskDate) ?? taskDate
        }
        taskDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: taskDate) ?? taskDate

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        let isErrand = parsed?["is_errand"] == "true"
        let place = selectedPlace
        let driveMin = Int(parsed?["drive_minutes"] ?? "15") ?? 15

        let newTask = LogisticsTask(
            id: UUID(),
            title: place?.name ?? parsed?["title"] ?? input,
            subtitle: place?.address ?? parsed?["address"] ?? "",
            address: place?.address ?? parsed?["address"] ?? "",
            time: fmt.string(from: taskDate),
            date: taskDate,
            driveMinutes: driveMin,
            parkMinutes: 3,
            icon: place?.categoryIcon ?? parsed?["icon"] ?? (isErrand ? "bag.fill" : "mappin.circle.fill"),
            iconColor: colorName(place?.categoryColor ?? .blue),
            status: .onTime,
            alert: nil,
            isErrand: isErrand,
            placeLat: place?.lat,
            placeLon: place?.lon
        )

        tasks.append(newTask)
        tasks.sort { $0.date < $1.date }
        lastAddedTask = newTask
        showSavePrompt = true
    }

    func saveToNextSession() {
        LogisticsPersistence.save(tasks)
    }

    func clearSaved() {
        LogisticsPersistence.clear()
    }

    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        LogisticsPersistence.save(tasks)
    }

    private func colorName(_ color: Color) -> String {
        switch color {
        case .red: return "red"
        case .blue: return "blue"
        case .green: return "green"
        case .orange: return "orange"
        case .purple: return "purple"
        case .pink: return "pink"
        default: return "blue"
        }
    }
}

// MARK: - Main View
struct LogisticsView: View {
    @StateObject private var vm = LogisticsViewModel()
    @StateObject private var locationManager = LocationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Urgent Banner
                    if let urgent = vm.urgentTask {
                        UrgentBanner(task: urgent).padding(.horizontal)
                    }

                    // Location bar
                    LocationBar(locationManager: locationManager)
                        .padding(.horizontal)

                    // Live Traffic
                    LiveTrafficCard(roads: vm.roads, totalMinutes: vm.totalDriveMinutes)
                        .padding(.horizontal)

                    // Today's Route
                    if !vm.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Today's Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.headline)
                                Spacer()
                                Text("\(vm.tasks.count) остановок")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(Array(vm.tasks.enumerated()), id: \.element.id) { i, task in
                                    TaskTimelineRow(
                                        task: task,
                                        isFirst: i == 0,
                                        isLast: i == vm.tasks.count - 1
                                    ) { vm.deleteTask(id: task.id) }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .padding(.horizontal)
                        }
                    } else {
                        EmptyRouteView()
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Logistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        vm.showAddTask = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $vm.showAddTask) {
                AddTaskSheet(vm: vm, locationManager: locationManager)
            }
            .alert("Сохранить маршрут?", isPresented: $vm.showSavePrompt) {
                Button("Сохранить на завтра") { vm.saveToNextSession() }
                Button("Только сегодня", role: .destructive) { vm.clearSaved() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Хочешь чтобы этот маршрут был доступен в следующий раз?")
            }
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }
}

// MARK: - Location Bar
struct LocationBar: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(locationManager.location != nil ? .blue : .secondary)
            if locationManager.location != nil {
                Text("Ты сейчас в \(locationManager.cityName.isEmpty ? "определяем..." : locationManager.cityName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Геолокация недоступна")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if locationManager.location != nil {
                Text("Актуально").font(.caption2).foregroundStyle(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.1)).cornerRadius(4)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Empty Route
struct EmptyRouteView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Маршрут пуст").font(.headline).foregroundStyle(.secondary)
            Text("Нажми карандаш вверху и напиши задачу — AI сам разберёт время и место")
                .font(.subheadline).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }
}

// MARK: - Urgent Banner
struct UrgentBanner: View {
    let task: LogisticsTask
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text("Leave Now").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                if let alert = task.alert {
                    Text(alert).font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(task.driveMinutes) min").font(.title3).fontWeight(.bold).foregroundStyle(.white)
                Text("5,2 km").font(.caption2).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .background(LinearGradient(
            colors: [Color(red:0.95,green:0.28,blue:0.28), Color(red:0.82,green:0.12,blue:0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .cornerRadius(18)
        .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Live Traffic Card
struct LiveTrafficCard: View {
    let roads: [TrafficRoad]
    let totalMinutes: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "car.fill").foregroundStyle(.secondary).font(.subheadline)
                    Text("Live Traffic").font(.subheadline).fontWeight(.semibold)
                }
                Spacer()
                Text("\(totalMinutes) min total").font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(roads) { road in
                    HStack(spacing: 10) {
                        Circle().fill(road.color).frame(width: 8, height: 8)
                        Text(road.name).font(.caption).frame(width: 100, alignment: .leading)
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 5)
                                RoundedRectangle(cornerRadius: 3).fill(road.color)
                                    .frame(width: geo.size.width * road.level, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Timeline Row
struct TaskTimelineRow: View {
    let task: LogisticsTask
    let isFirst: Bool
    let isLast: Bool
    let onDelete: () -> Void

    var statusView: some View {
        Group {
            switch task.status {
            case .onTime:
                Label("On Time", systemImage: "checkmark.circle.fill")
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.green)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.green.opacity(0.12)).cornerRadius(20)
            case .leaveNow:
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Leave Now")
                }
                .font(.caption2).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.red).cornerRadius(20)
            case .delayed:
                Label("Delayed", systemImage: "clock.badge.exclamationmark.fill")
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.orange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12)).cornerRadius(20)
            case .done:
                Label("Done", systemImage: "checkmark")
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(.systemGray5)).cornerRadius(20)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : Color(.systemGray4)).frame(width: 2, height: 16)
                ZStack {
                    Circle().fill(task.iconColorValue.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: task.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(task.iconColorValue)
                }
                if !isLast {
                    Rectangle().fill(Color(.systemGray4)).frame(width: 2)
                        .frame(height: task.alert != nil ? 82 : 54)
                }
            }
            .frame(width: 58)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 10)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title).font(.subheadline).fontWeight(.semibold)
                        Text(task.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusView
                }
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                        Text(task.time).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "car.fill").font(.caption2).foregroundStyle(.secondary)
                        Text("\(task.driveMinutes) min").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "parkingsign.circle").font(.caption2).foregroundStyle(.secondary)
                        Text("+\(task.parkMinutes) park").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                if let alert = task.alert {
                    HStack(spacing: 6) {
                        Image(systemName: task.status == .leaveNow ? "exclamationmark.circle.fill" : "lightbulb.fill")
                            .font(.caption2)
                            .foregroundStyle(task.status == .leaveNow ? Color.red : Color.blue)
                        Text(alert).font(.caption2).lineLimit(2)
                            .foregroundStyle(task.status == .leaveNow ? Color.red : Color(red:0.2,green:0.4,blue:0.9))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(task.status == .leaveNow ? Color.red.opacity(0.08) : Color.blue.opacity(0.07))
                    .cornerRadius(10).padding(.top, 8)
                }
                Spacer().frame(height: 16)
            }
            .padding(.trailing, 16)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @ObservedObject var vm: LogisticsViewModel
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss

    @State private var input = ""
    @State private var searchResults: [RichPlaceResult] = []
    @State private var selectedPlace: RichPlaceResult? = nil
    @State private var isSearchingPlaces = false
    @State private var showPlacePicker = false
    @State private var placeSearchQuery = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var placeFocused: Bool

    let examples = [
        "К стоматологу завтра в 11:30",
        "Купить молоко по дороге домой",
        "Постричься сегодня в 18:00",
        "Банк — перевод, 14:15",
        "Забрать посылку",
    ]

    var fromText: String {
        if let loc = locationManager.location {
            return locationManager.cityName.isEmpty ? "твоя геолокация" : "ты сейчас в \(locationManager.cityName)"
        }
        return "геолокация недоступна"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 56, height: 56)
                            Image(systemName: "sparkles").font(.title2).foregroundStyle(.white)
                        }
                        Text("Новая задача").font(.title3).bold()
                        Text("AI разберёт время, место и тип задачи")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // MARK: FROM (auto geolocation)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ОТКУДА").font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary).padding(.horizontal)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: "location.fill").font(.subheadline).foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Текущее местоположение").font(.subheadline).fontWeight(.medium)
                                Text(fromText).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if locationManager.location != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .padding(.horizontal)
                    }

                    // MARK: Task input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ЧТО НУЖНО СДЕЛАТЬ").font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary).padding(.horizontal)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                            if input.isEmpty {
                                Text("Например: к стоматологу завтра в 11:30...")
                                    .foregroundStyle(.tertiary).padding(14)
                            }
                            TextEditor(text: $input)
                                .focused($inputFocused)
                                .frame(minHeight: 70)
                                .padding(10)
                                .background(Color.clear)
                                .scrollContentBackground(.hidden)
                        }
                        .frame(minHeight: 70).padding(.horizontal)

                        // Example chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(examples, id: \.self) { ex in
                                    Button { input = ex; inputFocused = false } label: {
                                        Text(ex).font(.caption)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Color(.systemGray6))
                                            .foregroundStyle(.primary)
                                            .cornerRadius(20).lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // MARK: Place search (2GIS)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("КУДА (ПОИСК МЕСТА)").font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary).padding(.horizontal)

                        // Selected place card
                        if let place = selectedPlace {
                            SelectedPlaceCard(place: place) {
                                withAnimation { selectedPlace = nil; searchResults = [] }
                            }
                            .padding(.horizontal)
                        } else {
                            // Search field
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                    TextField("Поиск через 2ГИС...", text: $placeSearchQuery)
                                        .focused($placeFocused)
                                        .onSubmit { Task { await searchPlaces() } }
                                        .submitLabel(.search)
                                    if isSearchingPlaces { ProgressView().scaleEffect(0.7) }
                                    else if !placeSearchQuery.isEmpty {
                                        Button { placeSearchQuery = ""; searchResults = [] } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(searchResults.isEmpty ? 14 : 0)
                                .cornerRadius(14)

                                // Results
                                if !searchResults.isEmpty {
                                    Divider()
                                    VStack(spacing: 0) {
                                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { i, place in
                                            Button {
                                                withAnimation(.spring(response: 0.3)) {
                                                    selectedPlace = place
                                                    searchResults = []
                                                    placeSearchQuery = ""
                                                    placeFocused = false
                                                }
                                            } label: {
                                                PlaceResultRow(place: place)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            if i < searchResults.count - 1 { Divider().padding(.leading, 60) }
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(14)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }

                    // MARK: Smart tips
                    SmartTipsCard()
                        .padding(.horizontal)

                    // MARK: Add button
                    Button {
                        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task {
                            await vm.parseAndAddTask(input: input, selectedPlace: selectedPlace)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isParsingTask {
                                ProgressView().tint(.white)
                                Text("AI разбирает...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Добавить в маршрут")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(input.isEmpty ? Color(.systemGray4) : Color.blue)
                        .foregroundStyle(.white).cornerRadius(16)
                    }
                    .disabled(input.isEmpty || vm.isParsingTask)
                    .padding(.horizontal).padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onAppear { inputFocused = true }
            .onChange(of: placeSearchQuery) { query in
                if query.count >= 2 {
                    Task { await searchPlaces() }
                } else if query.isEmpty {
                    searchResults = []
                }
            }
        }
    }

    func searchPlaces() async {
        guard !placeSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchingPlaces = true
        let lat = locationManager.location?.coordinate.latitude
        let lon = locationManager.location?.coordinate.longitude
        let raw = (try? await NetworkManager.shared.searchPlace(
            query: placeSearchQuery, lat: lat, lon: lon
        )) ?? []
        searchResults = raw.map { RichPlaceResult(from: $0, userLocation: locationManager.location) }
        isSearchingPlaces = false
    }
}

// MARK: - Selected Place Card
struct SelectedPlaceCard: View {
    let place: RichPlaceResult
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(place.categoryColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: place.categoryIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(place.categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name).font(.subheadline).fontWeight(.bold).lineLimit(1)
                Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text(place.category).font(.caption2).foregroundStyle(place.categoryColor)
                    if !place.distanceText.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location").font(.caption2)
                            Text(place.distanceText)
                        }
                        .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary).font(.title3)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(place.categoryColor.opacity(0.3), lineWidth: 1.5))
        .shadow(color: place.categoryColor.opacity(0.1), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Place Result Row
struct PlaceResultRow: View {
    let place: RichPlaceResult

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(place.categoryColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: place.categoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(place.categoryColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(place.category).font(.caption2).foregroundStyle(place.categoryColor)
                    if !place.distanceText.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "location").font(.caption2).foregroundStyle(.secondary)
                            Text(place.distanceText).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if let rating = place.rating {
                        Text("·").foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.blue.opacity(0.7)).font(.title3)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Smart Tips
struct SmartTipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Умные функции", systemImage: "lightbulb.fill")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)

            VStack(spacing: 8) {
                LogisticsTipRow(icon: "bell.fill", color: .blue, text: "Напомнит когда выезжать с учётом пробок")
                LogisticsTipRow(icon: "cloud.rain.fill", color: .cyan, text: "Учтёт погоду — ливень = +15 мин")
                LogisticsTipRow(icon: "bag.fill", color: .orange, text: "«Купить молоко» — напомнит у магазина")
                LogisticsTipRow(icon: "figure.walk", color: .green, text: "Пробки 9 баллов? Предложит метро")
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.15), lineWidth: 1))
    }
}

struct LogisticsTipRow: View {
    let icon: String
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.caption).foregroundStyle(color).frame(width: 16)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}
