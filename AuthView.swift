import SwiftUI
import Combine

// MARK: - Auth View Model
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = AuthStorage.shared.isLoggedIn
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    func login(email: String, password: String) async {
        await MainActor.run { isLoading = true }
        do {
            let response = try await NetworkManager.shared.login(email: email, password: password)
            AuthStorage.shared.token = response.access_token
            await MainActor.run { isLoggedIn = true }
            NotificationCenter.default.post(name: .didLogin, object: nil)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        await MainActor.run { isLoading = false }
    }
    
    func register(email: String, password: String, name: String) async {
        await MainActor.run { isLoading = true }
        do {
            let response = try await NetworkManager.shared.register(email: email, password: password, name: name)
            AuthStorage.shared.token = response.access_token
            await MainActor.run { isLoggedIn = true }
            NotificationCenter.default.post(name: .didLogin, object: nil)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        await MainActor.run { isLoading = false }
    }
    
    func logout() {
        AuthStorage.shared.logout()
        isLoggedIn = false
    }
}
// MARK: - Auth View
struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 8) {
                    Text("AURA")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Color(red: 0.6, green: 0.4, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                        )
                    Text("AI-ассистент для жизни")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Form
                VStack(spacing: 16) {
                    if !isLoginMode {
                        AuraTextField(placeholder: "Имя", text: $name, icon: "person")
                    }
                    AuraTextField(placeholder: "Email", text: $email, icon: "envelope")
                    AuraTextField(placeholder: "Пароль", text: $password, icon: "lock", isSecure: true)
                }
                .padding(.horizontal, 24)
                
                // Button
                Button {
                    Task {
                        if isLoginMode {
                            await vm.login(email: email, password: password)
                        } else {
                            await vm.register(email: email, password: password, name: name)
                        }
                    }
                } label: {
                    ZStack {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isLoginMode ? "Войти" : "Создать аккаунт")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(colors: [Color(red: 0.5, green: 0.3, blue: 1.0), Color(red: 0.3, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                .disabled(vm.isLoading)
                
                // Toggle
                Button {
                    withAnimation { isLoginMode.toggle() }
                } label: {
                    Text(isLoginMode ? "Нет аккаунта? Зарегистрироваться" : "Уже есть аккаунт? Войти")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
        }
        .alert("Ошибка", isPresented: $vm.showError) {
            Button("OK") {}
        } message: {
            Text(vm.errorMessage)
        }
    }
}

// MARK: - Custom TextField
struct AuraTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .keyboardType(placeholder == "Email" ? .emailAddress : .default)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
