import Foundation

// MARK: - Models
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let user: UserResponse
}

struct UserResponse: Codable {
    let id: Int
    let email: String
    let username: String?
    let full_name: String?
    let avatar_url: String?
    let calorie_goal: Int?
    let created_at: String?
}

struct DailySummaryResponse: Codable {
    let total_calories: Int
    let total_protein: Double
    let total_carbs: Double
    let total_fat: Double
    let calorie_goal: Int
    let meals_count: Int
}

struct MealResponse: Codable {
    let id: Int
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let meal_type: String
    let created_at: String?
}

struct MovieResponse: Codable {
    let id: Int
    let title: String
    let year: Int?
    let rating: Double?
    let poster_url: String?
    let watched: Bool?
    let tmdb_id: Int?
}

struct VocabResponse: Codable {
    let id: Int
    let word: String
    let translation: String
    let learned: Bool
    let language: String?
}

struct StreakResponse: Codable {
    let streak_days: Int
}

// MARK: - Auth Storage
class AuthStorage {
    static let shared = AuthStorage()
    private let tokenKey = "auth_token"
    
    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }
    
    var isLoggedIn: Bool {
        token != nil && !(token?.isEmpty ?? true)
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}

// MARK: - API Error
enum APIError: Error {
    case networkError
    case serverError(String)
    case unauthorized
}

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()
    let BASE_URL = "http://13.61.189.232:8000"
    let session = URLSession.shared
    
    private func authHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let token = AuthStorage.shared.token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
    
    private func request<T: Codable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: BASE_URL + path) else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = method
        authHeaders().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard let result = try? JSONDecoder().decode(T.self, from: data) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errStr)
        }
        return result
    }
    
    // MARK: - Auth
    func login(email: String, password: String) async throws -> TokenResponse {
        guard let url = URL(string: BASE_URL + "/auth/login") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "username=\(email)&password=\(password)".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let result = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw APIError.serverError("Неверный email или пароль")
        }
        return result
    }
    
    func register(email: String, password: String, name: String) async throws -> TokenResponse {
        guard let url = URL(string: BASE_URL + "/auth/register") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["username": email, "email": email, "password": password, "full_name": name]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: req)
        guard let result = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw APIError.serverError("Ошибка регистрации")
        }
        return result
    }
    
    func getMe() async throws -> UserResponse {
        return try await request("/auth/me")
    }
    
    // MARK: - Food
    func getTodaySummary() async throws -> DailySummaryResponse {
        return try await request("/food/today")
    }
    
    func getMealHistory() async throws -> [MealResponse] {
        return try await request("/food/history")
    }
    
    // MARK: - Cinema
    func getTrending() async throws -> [MovieResponse] {
        return try await request("/cinema/trending")
    }
    
    func getMyMovies() async throws -> [MovieResponse] {
        return try await request("/cinema/my-list")
    }
    
    func searchMovies(query: String) async throws -> [MovieResponse] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request("/cinema/search?query=\(encoded)")
    }
    
    // MARK: - Languages
    func getVocabulary() async throws -> [VocabResponse] {
        return try await request("/languages/vocabulary")
    }
    
    func getLearningStreak() async throws -> Int {
        let response: StreakResponse = try await request("/languages/streak")
        return response.streak_days
    }
}
