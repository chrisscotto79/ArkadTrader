//
//  NetworkService.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Services/NetworkService.swift

import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - API Configuration
    private let baseURL = "https://api.arkadtrader.com" // Placeholder URL
    
    // MARK: - Generic Network Request
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
    
    // MARK: - Specific API Methods (for future use)
    func fetchUser(id: String) async throws -> User {
        return try await request(endpoint: "/users/\(id)", responseType: User.self)
    }
    
    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        return try await request(endpoint: "/leaderboard", responseType: [LeaderboardEntry].self)
    }
    
    func fetchPosts() async throws -> [Post] {
        return try await request(endpoint: "/posts", responseType: [Post].self)
    }
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
