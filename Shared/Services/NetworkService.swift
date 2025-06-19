// File: Shared/Services/NetworkService.swift

import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - API Configuration
    private let baseURL = "https://api.arkadtrader.com" // Your actual API URL
    private var authToken: String? {
        UserDefaults.standard.string(forKey: "auth_token")
    }
    
    // MARK: - Generic Network Request
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if required
        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NetworkError.serverError(httpResponse.statusCode)
            }
            
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
            
        } catch {
            throw NetworkError.requestFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Authentication Endpoints
    func login(email: String, password: String) async throws -> AuthResponse {
        let loginData = LoginRequest(email: email, password: password)
        let body = try JSONEncoder().encode(loginData)
        
        return try await request(
            endpoint: "/auth/login",
            method: .POST,
            body: body,
            responseType: AuthResponse.self,
            requiresAuth: false
        )
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws -> AuthResponse {
        let registerData = RegisterRequest(
            email: email,
            password: password,
            username: username,
            fullName: fullName
        )
        let body = try JSONEncoder().encode(registerData)
        
        return try await request(
            endpoint: "/auth/register",
            method: .POST,
            body: body,
            responseType: AuthResponse.self,
            requiresAuth: false
        )
    }
    
    // MARK: - User Profile Endpoints
    func fetchUser(id: String) async throws -> User {
        return try await request(endpoint: "/users/\(id)", responseType: User.self)
    }
    
    func updateProfile(_ profile: UpdateProfileRequest) async throws -> User {
        let body = try JSONEncoder().encode(profile)
        return try await request(
            endpoint: "/users/profile",
            method: .PUT,
            body: body,
            responseType: User.self
        )
    }
    
    func searchUsers(query: String, page: Int = 1) async throws -> SearchUsersResponse {
        return try await request(
            endpoint: "/users/search?q=\(query)&page=\(page)",
            responseType: SearchUsersResponse.self
        )
    }
    
    // MARK: - Trading Endpoints
    func fetchTrades(userId: String) async throws -> [Trade] {
        return try await request(endpoint: "/trades?userId=\(userId)", responseType: [Trade].self)
    }
    
    func createTrade(_ trade: CreateTradeRequest) async throws -> Trade {
        let body = try JSONEncoder().encode(trade)
        return try await request(
            endpoint: "/trades",
            method: .POST,
            body: body,
            responseType: Trade.self
        )
    }
    
    func updateTrade(id: String, _ trade: UpdateTradeRequest) async throws -> Trade {
        let body = try JSONEncoder().encode(trade)
        return try await request(
            endpoint: "/trades/\(id)",
            method: .PUT,
            body: body,
            responseType: Trade.self
        )
    }
    
    func deleteTrade(id: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/trades/\(id)",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - Social Features
    func followUser(userId: String) async throws -> FollowResponse {
        return try await request(
            endpoint: "/users/\(userId)/follow",
            method: .POST,
            responseType: FollowResponse.self
        )
    }
    
    func unfollowUser(userId: String) async throws -> FollowResponse {
        return try await request(
            endpoint: "/users/\(userId)/unfollow",
            method: .DELETE,
            responseType: FollowResponse.self
        )
    }
    
    func getFollowing(userId: String, page: Int = 1) async throws -> [User] {
        return try await request(
            endpoint: "/users/\(userId)/following?page=\(page)",
            responseType: [User].self
        )
    }
    
    func getFollowers(userId: String, page: Int = 1) async throws -> [User] {
        return try await request(
            endpoint: "/users/\(userId)/followers?page=\(page)",
            responseType: [User].self
        )
    }
    
    // MARK: - Posts/Feed Endpoints
    func fetchFeed(page: Int = 1) async throws -> [Post] {
        return try await request(
            endpoint: "/feed?page=\(page)",
            responseType: [Post].self
        )
    }
    
    func createPost(_ post: CreatePostRequest) async throws -> Post {
        let body = try JSONEncoder().encode(post)
        return try await request(
            endpoint: "/posts",
            method: .POST,
            body: body,
            responseType: Post.self
        )
    }
    
    func likePost(postId: String) async throws -> LikeResponse {
        return try await request(
            endpoint: "/posts/\(postId)/like",
            method: .POST,
            responseType: LikeResponse.self
        )
    }
    
    func unlikePost(postId: String) async throws -> LikeResponse {
        return try await request(
            endpoint: "/posts/\(postId)/like",
            method: .DELETE,
            responseType: LikeResponse.self
        )
    }
    
    // MARK: - Messaging Endpoints
    func getConversations() async throws -> [Conversation] {
        return try await request(endpoint: "/messages/conversations", responseType: [Conversation].self)
    }
    
    func getMessages(conversationId: String, page: Int = 1) async throws -> [Message] {
        return try await request(
            endpoint: "/messages/conversations/\(conversationId)?page=\(page)",
            responseType: [Message].self
        )
    }
    
    func sendMessage(_ message: SendMessageRequest) async throws -> Message {
        let body = try JSONEncoder().encode(message)
        return try await request(
            endpoint: "/messages",
            method: .POST,
            body: body,
            responseType: Message.self
        )
    }
    
    // MARK: - Leaderboard
    func fetchLeaderboard(timeframe: String = "weekly") async throws -> [LeaderboardEntry] {
        return try await request(
            endpoint: "/leaderboard?timeframe=\(timeframe)",
            responseType: [LeaderboardEntry].self
        )
    }
    
    // MARK: - Account Management
    func updateAccountSettings(_ settings: AccountSettingsRequest) async throws -> AccountSettings {
        let body = try JSONEncoder().encode(settings)
        return try await request(
            endpoint: "/users/settings",
            method: .PUT,
            body: body,
            responseType: AccountSettings.self
        )
    }
    
    func deleteAccount() async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/users/account",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
}

// MARK: - Request/Response Models
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let username: String
    let fullName: String
}

struct AuthResponse: Codable {
    let user: User
    let token: String
    let refreshToken: String
}

struct UpdateProfileRequest: Codable {
    let fullName: String?
    let bio: String?
    let profileImageURL: String?
}

struct CreateTradeRequest: Codable {
    let ticker: String
    let tradeType: TradeType
    let entryPrice: Double
    let quantity: Int
    let notes: String?
    let strategy: String?
}

struct UpdateTradeRequest: Codable {
    let exitPrice: Double?
    let notes: String?
    let strategy: String?
}

struct CreatePostRequest: Codable {
    let content: String
    let imageURL: String?
    let postType: PostType
    let tradeId: String? // If posting about a specific trade
}

struct SendMessageRequest: Codable {
    let recipientId: String
    let content: String
    let conversationId: String?
}

struct SearchUsersResponse: Codable {
    let users: [User]
    let totalCount: Int
    let page: Int
    let hasMore: Bool
}

struct FollowResponse: Codable {
    let isFollowing: Bool
    let followersCount: Int
}

struct LikeResponse: Codable {
    let isLiked: Bool
    let likesCount: Int
}

struct AccountSettingsRequest: Codable {
    let isPrivate: Bool?
    let pushNotifications: Bool?
    let emailNotifications: Bool?
}

struct AccountSettings: Codable {
    let isPrivate: Bool
    let pushNotifications: Bool
    let emailNotifications: Bool
}

struct EmptyResponse: Codable {
    // Empty response for DELETE operations
}

// MARK: - Supporting Types
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case requestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .requestFailed(let message):
            return "Request failed: \(message)"
        }
    }
}
