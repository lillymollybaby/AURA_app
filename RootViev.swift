import SwiftUI

struct RootView: View {
    @State private var isLoggedIn = AuthStorage.shared.isLoggedIn
    
    var body: some View {
        if isLoggedIn {
            ContentView()
        } else {
            AuthView()
                .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
                    isLoggedIn = true
                }
        }
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
}
