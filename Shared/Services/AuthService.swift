// File: Shared/Services/AuthService.swift

import Foundation

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    static let shared = AuthService()
    private let networkService = NetworkService.shared
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Authentication Methods
    func login(email: String, password: String) async throws {
        do {
            let authResponse = try await networkService.login(email: email, password: password)
            
            // Save auth token
            UserDefaults.standard.set(authResponse.token, forKey: "auth_token")
            UserDefaults.standard.set(authResponse.refreshToken, forKey: "refresh_token")
            
            // Update state
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            
            // Save auth state
            UserDefaults.standard.set(true, forKey: "isAuthenticated")
            saveUser(authResponse.user)
            
        } catch {
            print("Login failed: \(error)")
            throw error
        }
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws {
        do {
            let authResponse = try await networkService.register(
                email: email,
                password: password,
                username: username,
                fullName: fullName
            )
            
            // Save auth token
            UserDefaults.standard.set(authResponse.token, forKey: "auth_token")
            UserDefaults.standard.set(authResponse.refreshToken, forKey: "refresh_token")
            
            // Update state
            self.currentUser = authResponse.user
            self.isAuthenticated = true
            
            // Save auth state
            UserDefaults.standard.set(true, forKey: "isAuthenticated")
            saveUser(authResponse.user)
            
        } catch {
            print("Registration failed: \(error)")
            throw error
        }
    }
    
    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
        
        // Clear all auth data
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }
    
    func refreshToken() async throws {
        guard let refreshToken = UserDefaults.standard.string(forKey: "refresh_token") else {
            throw AuthError.noRefreshToken
        }
        
        // Implement token refresh logic
        // This would call your backend's refresh endpoint
        // For now, just throw error to force re-login
        throw AuthError.refreshTokenExpired
    }
    
    // MARK: - Profile Management
    func updateProfile(fullName: String?, bio: String?, profileImageURL: String? = nil) async throws -> User {
        let updateRequest = UpdateProfileRequest(
            fullName: fullName,
            bio: bio,
            profileImageURL: profileImageURL
        )
        
        do {
            let updatedUser = try await networkService.updateProfile(updateRequest)
            self.currentUser = updatedUser
            saveUser(updatedUser)
            return updatedUser
        } catch {
            print("Profile update failed: \(error)")
            throw error
        }
    }
    
    func fetchCurrentUser() async throws {
        guard let userId = currentUser?.id.uuidString else {
            throw AuthError.userNotFound
        }
        
        do {
            let user = try await networkService.fetchUser(id: userId)
            self.currentUser = user
            saveUser(user)
        } catch {
            print("Failed to fetch current user: \(error)")
            throw error
        }
    }
    
    // MARK: - Account Settings
    func updateAccountSettings(isPrivate: Bool? = nil, pushNotifications: Bool? = nil, emailNotifications: Bool? = nil) async throws -> AccountSettings {
        let settingsRequest = AccountSettingsRequest(
            isPrivate: isPrivate,
            pushNotifications: pushNotifications,
            emailNotifications: emailNotifications
        )
        
        do {
            return try await networkService.updateAccountSettings(settingsRequest)
        } catch {
            print("Settings update failed: \(error)")
            throw error
        }
    }
    
    func deleteAccount() async throws {
        do {
            try await networkService.deleteAccount()
            logout() // Clear local data after successful deletion
        } catch {
            print("Account deletion failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    private func checkAuthStatus() {
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        
        if isAuthenticated {
            loadUser()
            
            // Validate token is still valid
            Task {
                do {
                    try await fetchCurrentUser()
                } catch {
                    // Token might be expired, logout
                    print("Token validation failed, logging out")
                    logout()
                }
            }
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
    case noRefreshToken
    case refreshTokenExpired
    case invalidCredentials
    case accountLocked
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .noRefreshToken:
            return "No refresh token available"
        case .refreshTokenExpired:
            return "Refresh token expired. Please log in again."
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountLocked:
            return "Account is locked. Please contact support."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}

// MARK: - Social Features Service
@MainActor
class SocialService: ObservableObject {
    static let shared = SocialService()
    private let networkService = NetworkService.shared
    
    @Published var following: [User] = []
    @Published var followers: [User] = []
    
    private init() {}
    
    // MARK: - Following System
    func followUser(_ userId: String) async throws -> FollowResponse {
        do {
            let response = try await networkService.followUser(userId: userId)
            await loadFollowing() // Refresh following list
            return response
        } catch {
            print("Follow user failed: \(error)")
            throw error
        }
    }
    
    func unfollowUser(_ userId: String) async throws -> FollowResponse {
        do {
            let response = try await networkService.unfollowUser(userId: userId)
            await loadFollowing() // Refresh following list
            return response
        } catch {
            print("Unfollow user failed: \(error)")
            throw error
        }
    }
    
    func loadFollowing(userId: String? = nil) async {
        guard let currentUserId = userId ?? AuthService.shared.currentUser?.id.uuidString else { return }
        
        do {
            self.following = try await networkService.getFollowing(userId: currentUserId)
        } catch {
            print("Failed to load following: \(error)")
        }
    }
    
    func loadFollowers(userId: String? = nil) async {
        guard let currentUserId = userId ?? AuthService.shared.currentUser?.id.uuidString else { return }
        
        do {
            self.followers = try await networkService.getFollowers(userId: currentUserId)
        } catch {
            print("Failed to load followers: \(error)")
        }
    }
    
    // MARK: - Search
    func searchUsers(query: String) async throws -> SearchUsersResponse {
        do {
            return try await networkService.searchUsers(query: query)
        } catch {
            print("User search failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    func isFollowing(userId: String) -> Bool {
        return following.contains { $0.id.uuidString == userId }
    }
    
    func getFollowersCount(for userId: String) -> Int {
        // This would typically come from the user object or a separate API call
        return followers.count
    }
    
    func getFollowingCount(for userId: String) -> Int {
        return following.count
    }
}
