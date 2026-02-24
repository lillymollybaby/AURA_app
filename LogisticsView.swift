import SwiftUI

struct LogisticsView: View {
    @State private var searchQuery = ""
    @State private var places: [PlaceResult] = []
    @State private var trafficAdvice: TrafficAdviceResponse?
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search places...", text: $searchQuery)
                            .onSubmit { Task { await searchPlaces() } }
                    }
                    .padding(12).background(Color(.systemBackground)).cornerRadius(12)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2).padding(.horizontal).padding(.top, 8)

                    if let advice = trafficAdvice {
                        TrafficAdviceBanner(advice: advice).padding(.horizontal).padding(.top, 12)
                    }
                    LiveTrafficCard().padding(.horizontal).padding(.top, 12)

                    if isSearching {
                        ProgressView("Searching...").padding(.top, 20)
                    } else if !places.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse").foregroundColor(.secondary)
                                Text("Results").font(.headline)
                                Spacer()
                                Text("\(places.count) found").font(.caption).foregroundColor(.secondary)
                            }.padding(.horizontal).padding(.top, 20).padding(.bottom, 12)
                            ForEach(Array(places.enumerated()), id: \.offset) { idx, place in
                                PlaceRow(place: place).padding(.horizontal)
                                if idx < places.count - 1 { Divider().padding(.horizontal) }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch").foregroundColor(.secondary)
                                Text("Today's Route").font(.headline)
                            }.padding(.horizontal).padding(.top, 20).padding(.bottom, 12)
                            RouteItemView(icon: "briefcase.fill", iconColor: .orange, title: "Morning Standup", subtitle: "Office — 3rd Floor", time: "9:00", driveTime: "22 min", parking: "+3 park", statusText: "On Time", statusColor: .green, note: "Light traffic on your usual route", noteColor: Color.blue.opacity(0.15), noteIcon: "sparkle", noteIconColor: .blue)
                            RouteItemView(icon: "cross.fill", iconColor: .red, title: "Dentist Appointment", subtitle: "Dr. Klein — 45 Oak Ave", time: "11:30", driveTime: "18 min", parking: "+5 park", statusText: "Leave Now", statusColor: .red, note: "Leave by 11:05 — accident on Main St adds 7 min", noteColor: Color.red.opacity(0.12), noteIcon: "exclamationmark.triangle.fill", noteIconColor: .red)
                            RouteItemView(icon: "building.columns.fill", iconColor: .green, title: "Bank Transfer", subtitle: "Chase — Downtown Branch", time: "14:15", driveTime: "14 min", parking: "+4 park", statusText: "Delayed", statusColor: .orange, note: "Re-routed via Elm St — saves 6 min", noteColor: Color.blue.opacity(0.12), noteIcon: "sparkle", noteIconColor: .blue)
                        }
                    }
                    Spacer(minLength: 20)
                }
            }
            .background(Color(.systemGroupedBackground)).navigationTitle("Logistics").navigationBarTitleDisplayMode(.large)
        }
        .task {
            if let advice = try? await NetworkManager.shared.getTrafficAdvice(destination: "work") { trafficAdvice = advice }
        }
    }

    func searchPlaces() async {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        if let results = try? await NetworkManager.shared.searchPlace(query: searchQuery) { places = results }
        if let advice = try? await NetworkManager.shared.getTrafficAdvice(destination: searchQuery) { trafficAdvice = advice }
        isSearching = false
    }
}

struct TrafficAdviceBanner: View {
    let advice: TrafficAdviceResponse
    var bannerColor: Color {
        if advice.traffic_status.contains("сильн") { return .red }
        if advice.traffic_status.contains("умеренн") { return .orange }
        return .green
    }
    var body: some View {
        HStack {
            Image(systemName: "car.fill").foregroundColor(.white).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Traffic: \(advice.traffic_status)").font(.headline).foregroundColor(.white)
                Text(advice.advice).font(.caption).foregroundColor(.white.opacity(0.9)).lineLimit(3)
            }
            Spacer()
        }.padding().background(bannerColor).cornerRadius(14)
    }
}

struct PlaceRow: View {
    let place: PlaceResult
    var body: some View {
        HStack(spacing: 12) {
            ZStack { Circle().fill(Color.blue.opacity(0.12)).frame(width: 40, height: 40); Image(systemName: "mappin").foregroundColor(.blue) }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).font(.subheadline).fontWeight(.semibold)
                if let address = place.address, !address.isEmpty { Text(address).font(.caption).foregroundColor(.secondary) }
                if let type = place.type, !type.isEmpty { Text(type).font(.caption2).foregroundColor(.blue) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
        }.padding(.vertical, 8)
    }
}

struct LiveTrafficCard: View {
    let routes = [("I-90 West", Color.green), ("Main Street", Color.red), ("Oak Avenue", Color.orange), ("Highway 101", Color.green), ("Elm Street", Color.yellow)]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "car.fill").foregroundColor(.primary); Text("Live Traffic").font(.headline); Spacer(); Text("84 min total").font(.caption).foregroundColor(.secondary) }
            ForEach(routes, id: \.0) { route in
                HStack(spacing: 8) { Circle().fill(route.1).frame(width: 8, height: 8); Text(route.0).font(.subheadline); Spacer(); RoundedRectangle(cornerRadius: 3).fill(route.1.opacity(0.3)).frame(width: 80, height: 6) }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(14).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct RouteItemView: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String
    let time: String; let driveTime: String; let parking: String
    let statusText: String; let statusColor: Color
    let note: String?; let noteColor: Color; let noteIcon: String; let noteIconColor: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 40, height: 40)
                    .overlay(Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 16)))
                Rectangle().fill(Color(.systemGray5)).frame(width: 2).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(title).font(.headline); Spacer(); StatusBadge(text: statusText, color: statusColor) }
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label(time, systemImage: "clock").font(.caption).foregroundColor(.secondary)
                    Label(driveTime, systemImage: "car.fill").font(.caption).foregroundColor(.secondary)
                    Label(parking, systemImage: "p.circle").font(.caption).foregroundColor(.secondary)
                }
                if let note = note {
                    HStack(spacing: 6) {
                        if !noteIcon.isEmpty { Image(systemName: noteIcon).font(.caption2).foregroundColor(noteIconColor) }
                        Text(note).font(.caption).foregroundColor(noteIconColor == .red ? .red : .blue)
                    }.padding(.horizontal, 10).padding(.vertical, 6).background(noteColor).cornerRadius(8)
                }
                Spacer(minLength: 16)
            }
        }.padding(.horizontal)
    }
}

struct StatusBadge: View {
    let text: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            if color == .red { Image(systemName: "exclamationmark.triangle.fill").font(.caption2) }
            else if color == .green { Image(systemName: "checkmark.circle.fill").font(.caption2) }
            Text(text).font(.caption).fontWeight(.semibold)
        }
        .foregroundColor(color == .orange ? .orange : .white)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(color == .orange ? Color.orange.opacity(0.15) : color).cornerRadius(20)
    }
}
