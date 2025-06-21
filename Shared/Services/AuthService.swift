// File: Shared/Services/AuthService.swift

import Foundation

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    static let shared = AuthService()
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Mock Authentication Methods
    func login(email: String, password: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // For testing: any email/password combination works
        // In production, this would validate against a backend
        let mockUser = User(
            email: email,
            username: email.components(separatedBy: "@").first ?? "user",
            fullName: "Test User"
        )
        
        // Save to UserDefaults
        self.currentUser = mockUser
        self.isAuthenticated = true
        
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        saveUser(mockUser)
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Create new user
        let newUser = User(
            email: email,
            username: username,
            fullName: fullName
        )
        
        // Save to UserDefaults
        self.currentUser = newUser
        self.isAuthenticated = true
        
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        saveUser(newUser)
    }
    
    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
        
        // Clear all auth data
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
    
    // MARK: - Profile Management
    func updateProfile(fullName: String?, bio: String?) async throws -> User {
        guard var user = currentUser else {
            throw AuthError.userNotFound
        }
        
        // Update user properties
        if let fullName = fullName {
            user.fullName = fullName
        }
        if let bio = bio {
            user.bio = bio
        }
        
        // Save updated user
        self.currentUser = user
        saveUser(user)
        
        return user
    }
    
    // MARK: - Private Methods
    private func checkAuthStatus() {
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        
        if isAuthenticated {
            loadUser()
        }
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
    
    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
        }
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case userNotFound
    case invalidCredentials
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}
