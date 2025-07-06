//
//  ProfileViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Profile/ViewModels/ProfileViewModel.swift

import Foundation

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var showEditProfile = false
    
    private let authService = FirebaseAuthService.shared
    
    init() {
        loadUserProfile()
    }
    
    func loadUserProfile() {
        self.user = authService.currentUser
    }
    
    func updateProfile(fullName: String, bio: String?) {
        guard var currentUser = user else { return }
        
        currentUser.fullName = fullName
        currentUser.bio = bio
        
        self.user = currentUser
        authService.currentUser = currentUser
        
        // Save updated user
        if let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
    
    func logout() {
        authService.logout()
    }
}
