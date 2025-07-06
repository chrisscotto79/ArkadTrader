// File: Core/Profile/ViewModels/ProfileViewModel.swift
// Simplified Profile ViewModel

import Foundation

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    
    private let authService = FirebaseAuthService.shared
    
    init() {
        loadUserProfile()
    }
    
    func loadUserProfile() {
        self.user = authService.currentUser
    }
    
    func updateProfile(fullName: String, bio: String?) {
        Task {
            do {
                try await authService.updateProfile(fullName: fullName, bio: bio)
                loadUserProfile()
            } catch {
                print("Error updating profile: \(error)")
            }
        }
    }
    
    func logout() {
        Task {
            await authService.logout()
        }
    }
}
