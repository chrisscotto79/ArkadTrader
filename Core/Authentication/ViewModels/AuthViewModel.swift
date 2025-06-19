//
//  AuthViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Authentication/ViewModels/AuthViewModel.swift

import Foundation

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var username = ""
    @Published var fullName = ""
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = AuthService.shared
    
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
            showErrorMessage("Login failed. Please try again.")
        }
        
        isLoading = false
    }
    
    func register() async {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty, !fullName.isEmpty else {
            showErrorMessage("Please fill in all fields")
            return
        }
        
        isLoading = true
        
        do {
            try await authService.register(email: email, password: password, username: username, fullName: fullName)
            clearFields()
        } catch {
            showErrorMessage("Registration failed. Please try again.")
        }
        
        isLoading = false
    }
    
    func logout() {
        authService.logout()
        clearFields()
    }
    
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
}
