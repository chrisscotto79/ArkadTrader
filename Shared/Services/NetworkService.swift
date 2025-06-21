// File: Shared/Services/NetworkService.swift

import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - API Configuration
    private let baseURL = "https://api.arkadtrader.com" // Future API URL
    
    // MARK: - Error Types
    enum NetworkError: Error, LocalizedError {
        case notImplemented
        case invalidURL
        case noData
        
        var errorDescription: String? {
            switch self {
            case .notImplemented:
                return "This feature is not yet implemented"
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            }
        }
    }
    
    // MARK: - Placeholder Methods
    
    // These methods will be implemented when the backend is ready
    // For now, they throw notImplemented error
    
    func fetchTrades(userId: String) async throws -> [Trade] {
        throw NetworkError.notImplemented
    }
    
    func fetchLeaderboard(timeframe: String = "weekly") async throws -> [LeaderboardEntry] {
        throw NetworkError.notImplemented
    }
    
    func fetchFeed(page: Int = 1) async throws -> [Post] {
        throw NetworkError.notImplemented
    }
    
    // MARK: - Future Implementation
    // When the backend is ready, replace the mock implementations
    // in AuthService and DataService with actual network calls
}

// MARK: - Request/Response Models (for future use)
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
    let tradeId: String?
}
