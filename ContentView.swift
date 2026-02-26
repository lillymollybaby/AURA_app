import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LogisticsView()
                .tabItem { Label("Logistics", systemImage: "location") }
                .tag(0)
            LanguagesView()
                .tabItem { Label("Languages", systemImage: "character.book.closed") }
                .tag(1)
            CinemaView()
                .tabItem { Label("Cinema", systemImage: "film") }
                .tag(2)
            FoodView()
                .tabItem { Label("Food", systemImage: "fork.knife") }
                .tag(3)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
    }
}
