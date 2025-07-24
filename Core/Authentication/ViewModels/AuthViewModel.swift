// File: Core/Authentication/ViewModels/AuthViewModel.swift
// Fixed Auth ViewModel

import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var fullName = ""
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    var currentUser: User? {
        authService.currentUser
    }
    
    // ✅ Add the missing isLoading property
    var isLoading: Bool {
        authService.isLoading
    }
    
    func login() async {
        do {
            try await authService.login(email: email, password: password)
            clearFields()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func register() async {
        do {
            try await authService.register(
                email: email,
                password: password,
                username: username,
                fullName: fullName
            )
            clearFields()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // ✅ Add the missing isUsernameAvailable method
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        return try await authService.isUsernameAvailable(username)
    }
    
    func logout() {
        Task {
            await authService.logout()
            clearFields()
        }
    }
    
    private func clearFields() {
        email = ""
        password = ""
        username = ""
        fullName = ""
    }
}
