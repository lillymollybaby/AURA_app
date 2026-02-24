import SwiftUI

struct RootView: View {
    @State private var isLoggedIn: Bool = AuthStorage.shared.token != nil
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "onboarding_completed")

    var body: some View {
        Group {
            if showOnboarding && !isLoggedIn {
                OnboardingView {
                    showOnboarding = false
                }
            } else if isLoggedIn {
                ContentView()
                    .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
                        isLoggedIn = false
                        showOnboarding = false
                    }
            } else {
                AuthView()
                    .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
                        isLoggedIn = true
                    }
            }
        }
        .onAppear {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleDinnerReminder()
        }
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
    static let didLogout = Notification.Name("didLogout")
}
