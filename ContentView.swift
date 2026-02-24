import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            LogisticsView().tabItem { Image(systemName: "location.fill"); Text("Logistics") }.tag(0)
            LanguagesView().tabItem { Image(systemName: "character.book.closed.fill"); Text("Languages") }.tag(1)
            CinemaView().tabItem { Image(systemName: "film.fill"); Text("Cinema") }.tag(2)
            FoodView().tabItem { Image(systemName: "fork.knife"); Text("Food") }.tag(3)
            ProfileView().tabItem { Image(systemName: "person.fill"); Text("Profile") }.tag(4)
        }
        .accentColor(.blue)
    }
}
