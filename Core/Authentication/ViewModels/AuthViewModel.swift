// File: Core/Authentication/ViewModels/AuthViewModel.swift
// Updated AuthViewModel for Firebase integration

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var fullName = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirestoreService.shared
    
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    var currentUser: User? {
        authService.currentUser
    }
    
    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            showErrorMessage("Please fill in all fields")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.login(email: email, password: password)
            clearFields()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func register() async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !fullName.isEmpty else {
            showErrorMessage("Please fill in all fields")
            return
        }
        
        // Basic validation
        guard isValidEmail(email) else {
            showErrorMessage("Please enter a valid email address")
            return
        }
        
        guard password.count >= 6 else {
            showErrorMessage("Password must be at least 6 characters")
            return
        }
        
        guard isValidUsername(username) else {
            showErrorMessage("Username can only contain letters, numbers, and underscores")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.register(email: email, password: password, username: username, fullName: fullName)
            clearFields()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func updateProfile(fullName: String?, bio: String?) async throws {
        try await authService.updateProfile(fullName: fullName, bio: bio)
    }
    
    func resetPassword(email: String) async {
        guard !email.isEmpty else {
            showErrorMessage("Please enter your email address")
            return
        }
        
        guard isValidEmail(email) else {
            showErrorMessage("Please enter a valid email address")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.resetPassword(email: email)
            showSuccessMessage("Password reset email sent!")
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func deleteAccount() async {
        isLoading = true
        
        do {
            try await authService.deleteAccount()
            clearFields()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func logout() {
        Task {
            await authService.logout()
            clearFields()
        }
    }
    
    // MARK: - Private Methods
    
    private func clearFields() {
        email = ""
        password = ""
        username = ""
        fullName = ""
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccessMessage(_ message: String) {
        // For success messages, you might want a separate state
        errorMessage = message
        showError = true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[A-Za-z0-9_]+$"
        return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username) &&
               username.count >= 3 && username.count <= 20
    }
}
