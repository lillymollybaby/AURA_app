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
    let date: String?
    let total_calories: Double
    let total_proteins: Double
    let total_fats: Double
    let total_carbs: Double
    let meals: [MealResponse]?
    let ai_advice: String?
    
    var calorie_goal: Int { 2200 }
    var total_protein: Double { total_proteins }
    var total_fat: Double { total_fats }
    var total_carbs_compat: Double { total_carbs }
    var meals_count: Int { meals?.count ?? 0 }
}

struct MealResponse: Codable {
    let id: Int
    let name: String
    let calories: Double
    let proteins: Double
    let fats: Double
    let carbs: Double
    let meal_type: String?
    let eaten_at: String?
    let ai_analysis: String?
    
    // Совместимость со старым UI
    var protein: Double { proteins }
    var fat: Double { fats }
    var created_at: String? { eaten_at }
}

struct MovieResponse: Codable {
    let id: Int?
    let tmdb_id: Int?
    let title: String
    let year: Int?
    let rating: Double?
    let poster_url: String?
    let watched: Bool?
    let overview: String?
    let review: String?
}

struct MovieSearchResult: Codable {
    let results: [MovieResponse]
}

struct VocabResponse: Codable {
    let id: Int
    let word: String
    let translation: String
    let example: String?
    let language: String?
    let learned: Bool
}

struct StreakResponse: Codable {
    let total_words: Int?
    let learned_words: Int?
    let streak_days: Int
    let progress_percent: Int?
}

struct PlaceResult: Codable {
    let name: String
    let address: String?
    let lat: Double?
    let lon: Double?
    let type: String?
}

struct PlaceSearchResponse: Codable {
    let results: [PlaceResult]
}

struct RouteResponse: Codable {
    let distance_km: Double
    let duration_min: Int
    let status: String
}

struct TrafficAdviceResponse: Codable {
    let destination: String
    let traffic_status: String
    let advice: String
    let hour: Int
}

struct DinnerIdeasResponse: Codable {
    let ideas: String
    let calories_remaining: Double
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
enum APIError: Error, LocalizedError {
    case networkError
    case serverError(String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "Нет подключения к серверу"
        case .serverError(let msg): return msg
        case .unauthorized: return "Необходима авторизация"
        }
    }
}

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()
    let BASE_URL = "https://aura-api.ddns.net"
    let session = URLSession.shared
    
    private func authHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let token = AuthStorage.shared.token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
    
    func request<T: Codable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
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
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(errStr)
        }
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
    
    func analyzeFoodPhoto(imageData: Data, mealType: String = "snack") async throws -> MealResponse {
        guard let url = URL(string: BASE_URL + "/food/analyze-photo?meal_type=\(mealType)") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = AuthStorage.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard let result = try? JSONDecoder().decode(MealResponse.self, from: data) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errStr)
        }
        return result
    }
    
    func getDinnerIdeas() async throws -> DinnerIdeasResponse {
        return try await request("/food/dinner-ideas", method: "POST")
    }
    
    func deleteMeal(id: Int) async throws {
        let _: [String: String] = try await request("/food/meal/\(id)", method: "DELETE")
    }
    
    // MARK: - Cinema
    func getTrending() async throws -> [MovieResponse] {
        let response: MovieSearchResult = try await request("/cinema/trending")
        return response.results
    }
    
    func getMyMovies() async throws -> [MovieResponse] {
        return try await request("/cinema/my-list")
    }
    
    func searchMovies(query: String) async throws -> [MovieResponse] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: MovieSearchResult = try await request("/cinema/search?q=\(encoded)")
        return response.results
    }
    
    func markWatched(tmdbId: Int, review: String? = nil) async throws -> MovieResponse {
        var path = "/cinema/watched/\(tmdbId)"
        if let review = review {
            let encoded = review.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? review
            path += "?review=\(encoded)"
        }
        return try await request(path, method: "POST")
    }
    
    // MARK: - Languages
    func getVocabulary() async throws -> [VocabResponse] {
        return try await request("/languages/vocabulary")
    }
    
    func getLearningStreak() async throws -> Int {
        let response: StreakResponse = try await request("/languages/streak")
        return response.streak_days
    }
    
    func markWordLearned(wordId: Int) async throws {
        let _: [String: String] = try await request("/languages/vocabulary/\(wordId)/learned", method: "PATCH")
    }
    
    // MARK: - Logistics
    func searchPlace(query: String, lat: Double? = nil, lon: Double? = nil) async throws -> [PlaceResult] {
        var path = "/logistics/search-place?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        if let lat = lat, let lon = lon {
            path += "&lat=\(lat)&lon=\(lon)"
        }
        let response: PlaceSearchResponse = try await request(path)
        return response.results
    }
    
    func getRoute(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) async throws -> RouteResponse {
        struct RouteRequest: Codable {
            let from_lat: Double
            let from_lon: Double
            let to_lat: Double
            let to_lon: Double
            let transport: String
        }
        let body = RouteRequest(from_lat: fromLat, from_lon: fromLon, to_lat: toLat, to_lon: toLon, transport: "car")
        return try await request("/logistics/route", method: "POST", body: body)
    }
    
    func getTrafficAdvice(destination: String) async throws -> TrafficAdviceResponse {
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        return try await request("/logistics/traffic-advice?destination=\(encoded)")
    }
}
