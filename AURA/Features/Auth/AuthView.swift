import SwiftUI

// MARK: - Splash Screen
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.1
    @State private var ringOpacity: Double = 0
    @State private var ring2Scale: CGFloat = 0.1
    @State private var subtitleOpacity: Double = 0
    @State private var isDone = false
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            SplashBackground()
            SplashContent(
                logoScale: logoScale, logoOpacity: logoOpacity,
                ringScale: ringScale, ringOpacity: ringOpacity,
                ring2Scale: ring2Scale, subtitleOpacity: subtitleOpacity
            )
        }
        .opacity(isDone ? 0 : 1)
        .onAppear { animateSplash() }
    }

    func animateSplash() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0; logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.4)) {
            ringScale = 1.0; ringOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 1.2).delay(0.6)) { ring2Scale = 1.0 }
        withAnimation(.easeIn(duration: 0.6).delay(0.8)) { subtitleOpacity = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) { isDone = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onFinish() }
        }
    }
}

struct SplashBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red:0.97,green:0.97,blue:1.0), Color(red:0.93,green:0.95,blue:1.0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            Circle().fill(Color(red:0.55,green:0.45,blue:1.0).opacity(0.12))
                .frame(width:320,height:320).blur(radius:60).offset(x:-80,y:-120)
            Circle().fill(Color(red:0.3,green:0.6,blue:1.0).opacity(0.10))
                .frame(width:280,height:280).blur(radius:60).offset(x:100,y:160)
        }.ignoresSafeArea()
    }
}

struct SplashContent: View {
    let logoScale, logoOpacity, ringScale, ringOpacity, ring2Scale, subtitleOpacity: Double

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SplashLogo(logoScale:logoScale, logoOpacity:logoOpacity, ringScale:ringScale, ringOpacity:ringOpacity, ring2Scale:ring2Scale)
            VStack(spacing: 6) {
                Text("AURA")
                    .font(.system(size:28, weight:.ultraLight, design:.serif)).tracking(12)
                    .foregroundStyle(LinearGradient(colors:[Color(red:0.3,green:0.3,blue:0.5),Color(red:0.5,green:0.4,blue:0.7)], startPoint:.leading, endPoint:.trailing))
                    .opacity(logoOpacity)
                Text("AI-ассистент для жизни")
                    .font(.system(size:13, weight:.light)).tracking(2)
                    .foregroundColor(Color(red:0.5,green:0.5,blue:0.6))
                    .opacity(subtitleOpacity)
            }.padding(.top, 20)
            Spacer()
            SplashDots(subtitleOpacity: subtitleOpacity)
        }
    }
}

struct SplashLogo: View {
    let logoScale, logoOpacity, ringScale, ringOpacity, ring2Scale: Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(LinearGradient(colors:[Color(red:0.55,green:0.45,blue:1.0).opacity(0.3),Color(red:0.3,green:0.6,blue:1.0).opacity(0.1)], startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:1)
                .frame(width:140,height:140).scaleEffect(ring2Scale).opacity(ringOpacity*0.5)
            Circle()
                .stroke(LinearGradient(colors:[Color(red:0.55,green:0.45,blue:1.0).opacity(0.5),Color.clear], startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:1.5)
                .frame(width:100,height:100).scaleEffect(ringScale).opacity(ringOpacity)
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width:80,height:80)
                    .shadow(color:Color(red:0.55,green:0.45,blue:1.0).opacity(0.2), radius:20, x:0, y:8)
                Circle()
                    .stroke(LinearGradient(colors:[Color.white.opacity(0.8),Color.white.opacity(0.2)], startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:1)
                    .frame(width:80,height:80)
                Text("A").font(.system(size:34, weight:.thin, design:.serif))
                    .foregroundStyle(LinearGradient(colors:[Color(red:0.55,green:0.45,blue:1.0),Color(red:0.3,green:0.5,blue:1.0)], startPoint:.topLeading, endPoint:.bottomTrailing))
            }.scaleEffect(logoScale).opacity(logoOpacity)
        }
    }
}

struct SplashDots: View {
    let subtitleOpacity: Double
    @State private var animate = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle().fill(Color(red:0.55,green:0.45,blue:1.0).opacity(0.4))
                    .frame(width:5,height:5)
                    .scaleEffect(animate ? 1.0 : 0.3)
                    .animation(.easeInOut(duration:0.6).repeatForever().delay(Double(i)*0.2), value:animate)
            }
        }
        .opacity(subtitleOpacity).padding(.bottom, 60)
        .onAppear { animate = true }
    }
}

// MARK: - Auth View
struct AuthView: View {
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showContent = false

    var body: some View {
        ZStack {
            AuthBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    AuthHeader(isLogin: isLogin, showContent: showContent)
                    AuthCard(
                        isLogin: $isLogin, email: $email, password: $password,
                        fullName: $fullName, isLoading: $isLoading,
                        errorMessage: $errorMessage, showContent: showContent,
                        onSubmit: { Task { await performAuth() } }
                    )
                    if showContent {
                        Text("Входя в аккаунт, вы соглашаетесь с условиями использования")
                            .font(.system(size:11, weight:.light))
                            .foregroundColor(Color(red:0.6,green:0.6,blue:0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal,40).padding(.top,24).opacity(0.7)
                    }
                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear { withAnimation { showContent = true } }
    }

    func performAuth() async {
        guard !email.isEmpty, !password.isEmpty else { errorMessage = "Заполните все поля"; return }
        isLoading = true; errorMessage = ""
        do {
            if isLogin {
                let r = try await NetworkManager.shared.login(email: email, password: password)
                AuthStorage.shared.token = r.access_token
                NotificationCenter.default.post(name: .didLogin, object: nil)
            } else {
                guard !fullName.isEmpty else { errorMessage = "Введите имя"; isLoading = false; return }
                let r = try await NetworkManager.shared.register(email: email, password: password, name: fullName)
                AuthStorage.shared.token = r.access_token
                NotificationCenter.default.post(name: .didLogin, object: nil)
            }
        } catch { withAnimation { errorMessage = error.localizedDescription } }
        isLoading = false
    }
}

struct AuthBackground: View {
    var body: some View {
        ZStack {
            Color(red:0.97,green:0.97,blue:1.0).ignoresSafeArea()
            Circle().fill(Color(red:0.55,green:0.45,blue:1.0).opacity(0.1))
                .frame(width:400,height:400).blur(radius:80).offset(x:-100,y:-200)
            Circle().fill(Color(red:0.3,green:0.6,blue:1.0).opacity(0.08))
                .frame(width:300,height:300).blur(radius:70).offset(x:120,y:200)
        }.ignoresSafeArea()
    }
}

struct AuthHeader: View {
    let isLogin: Bool
    let showContent: Bool
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width:64,height:64)
                    .shadow(color:Color(red:0.55,green:0.45,blue:1.0).opacity(0.15), radius:16, x:0, y:6)
                Text("A").font(.system(size:28, weight:.thin, design:.serif))
                    .foregroundStyle(LinearGradient(colors:[Color(red:0.55,green:0.45,blue:1.0),Color(red:0.3,green:0.5,blue:1.0)], startPoint:.top, endPoint:.bottom))
            }
            Text(isLogin ? "С возвращением" : "Добро пожаловать")
                .font(.system(size:26, weight:.light, design:.serif))
                .foregroundColor(Color(red:0.2,green:0.2,blue:0.3))
            Text(isLogin ? "Войдите чтобы продолжить" : "Создайте аккаунт AURA")
                .font(.system(size:14, weight:.light))
                .foregroundColor(Color(red:0.5,green:0.5,blue:0.6))
        }
        .padding(.top,70).padding(.bottom,40)
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
        .animation(.spring(response:0.6).delay(0.1), value:showContent)
    }
}

struct AuthCard: View {
    @Binding var isLogin: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var fullName: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    let showContent: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            AuthTabSwitcher(isLogin: $isLogin, onSwitch: { errorMessage = "" })
            AuthFields(isLogin: isLogin, email: $email, password: $password, fullName: $fullName)
            if !errorMessage.isEmpty { AuthError(message: errorMessage) }
            AuthButton(isLogin: isLogin, isLoading: isLoading, onTap: onSubmit)
            if isLogin {
                Button("Забыли пароль?") {}
                    .font(.system(size:13, weight:.light))
                    .foregroundColor(Color(red:0.5,green:0.5,blue:0.7))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.7))
        .cornerRadius(28)
        .shadow(color:Color(red:0.4,green:0.3,blue:0.8).opacity(0.08), radius:24, x:0, y:12)
        .overlay(RoundedRectangle(cornerRadius:28).stroke(LinearGradient(colors:[Color.white.opacity(0.8),Color.white.opacity(0.2)], startPoint:.topLeading, endPoint:.bottomTrailing), lineWidth:1))
        .padding(.horizontal, 24)
        .opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 30)
        .animation(.spring(response:0.6).delay(0.2), value:showContent)
    }
}

struct AuthTabSwitcher: View {
    @Binding var isLogin: Bool
    let onSwitch: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            ForEach(["Вход","Регистрация"], id:\.self) { tab in
                let active = (tab == "Вход") == isLogin
                Button {
                    withAnimation(.spring(response:0.4)) { isLogin = (tab=="Вход"); onSwitch() }
                } label: {
                    Text(tab)
                        .font(.system(size:14, weight: active ? .medium : .light))
                        .foregroundColor(active ? Color(red:0.4,green:0.3,blue:0.8) : Color(red:0.5,green:0.5,blue:0.6))
                        .frame(maxWidth:.infinity).padding(.vertical,10)
                        .background(active ? Color.white.opacity(0.9) : Color.clear)
                        .cornerRadius(10)
                }
            }
        }
        .padding(4).background(Color(red:0.93,green:0.93,blue:0.97).opacity(0.8)).cornerRadius(14)
    }
}

struct AuthFields: View {
    let isLogin: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var fullName: String
    var body: some View {
        VStack(spacing: 12) {
            if !isLogin {
                GlassField(icon:"person", placeholder:"Имя", text:$fullName)
                    .transition(.move(edge:.top).combined(with:.opacity))
            }
            GlassField(icon:"envelope", placeholder:"Email", text:$email, keyboard:.emailAddress)
            GlassField(icon:"lock", placeholder:"Пароль", text:$password, isSecure:true)
        }
    }
}

struct AuthError: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName:"exclamationmark.circle").font(.caption)
            Text(message).font(.caption)
        }
        .foregroundColor(Color(red:0.8,green:0.3,blue:0.3))
        .padding(.horizontal,12).padding(.vertical,8)
        .background(Color(red:1.0,green:0.94,blue:0.94)).cornerRadius(10)
        .transition(.opacity)
    }
}

struct AuthButton: View {
    let isLogin: Bool
    let isLoading: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isLoading { ProgressView().tint(.white) }
                else {
                    Text(isLogin ? "Войти" : "Создать аккаунт")
                        .font(.system(size:15, weight:.medium)).foregroundColor(.white)
                }
            }
            .frame(maxWidth:.infinity).padding(.vertical,16)
            .background(LinearGradient(colors:[Color(red:0.5,green:0.4,blue:0.9),Color(red:0.35,green:0.5,blue:1.0)], startPoint:.leading, endPoint:.trailing))
            .cornerRadius(16)
            .shadow(color:Color(red:0.4,green:0.3,blue:0.9).opacity(0.3), radius:12, x:0, y:6)
        }
        .disabled(isLoading).scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.spring(response:0.3), value:isLoading)
    }
}

// MARK: - Glass Field
struct GlassField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size:14, weight:.light))
                .foregroundColor(focused ? Color(red:0.5,green:0.4,blue:0.9) : Color(red:0.6,green:0.6,blue:0.7))
                .frame(width:18).animation(.easeInOut(duration:0.2), value:focused)
            if isSecure {
                SecureField(placeholder, text:$text)
                    .font(.system(size:15, weight:.light)).focused($focused)
            } else {
                TextField(placeholder, text:$text)
                    .font(.system(size:15, weight:.light))
                    .keyboardType(keyboard).autocapitalization(.none).focused($focused)
            }
        }
        .padding(.horizontal,16).padding(.vertical,14)
        .background(RoundedRectangle(cornerRadius:14)
            .fill(focused ? Color.white : Color(red:0.96,green:0.96,blue:0.99))
            .animation(.easeInOut(duration:0.2), value:focused))
        .overlay(RoundedRectangle(cornerRadius:14)
            .stroke(focused ? Color(red:0.5,green:0.4,blue:0.9).opacity(0.4) : Color(red:0.88,green:0.88,blue:0.94), lineWidth:1)
            .animation(.easeInOut(duration:0.2), value:focused))
    }
}
