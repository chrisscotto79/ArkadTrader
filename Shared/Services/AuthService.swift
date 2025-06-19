//
//  AuthService.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Services/AuthService.swift

import Foundation

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    static let shared = AuthService()
    
    private init() {
        // Check if user is already logged in (from UserDefaults or Keychain)
        checkAuthStatus()
    }
    
    func login(email: String, password: String) async throws {
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // For MVP, create a mock user
        let user = User(email: email, username: "user123", fullName: "Test User")
        
        self.currentUser = user
        self.isAuthenticated = true
        
        // Save auth state
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        saveUser(user)
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws {
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let user = User(email: email, username: username, fullName: fullName)
        
        self.currentUser = user
        self.isAuthenticated = true
        
        // Save auth state
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        saveUser(user)
    }
    
    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
        
        // Clear auth state
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
    
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
