//
//  ClickableUsername.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


//
//  ClickableUsername.swift
//  ArkadTrader
//
//  CREATE NEW FILE: Shared/Components/ClickableUsername.swift
//  Reusable clickable username component
//

import SwiftUI

struct ClickableUsername: View {
    let userId: String
    let username: String
    let font: Font
    let color: Color
    
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(
        userId: String,
        username: String,
        font: Font = .subheadline,
        color: Color = .primary
    ) {
        self.userId = userId
        self.username = username
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Button(action: {
            handleProfileTap()
        }) {
            HStack(spacing: 4) {
                Text("@\(username)")
                    .font(font)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                if isLoadingUser {
                    ProgressView()
                        .scaleEffect(0.5)
                        .foregroundColor(color)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                OtherUserProfileView(user: profileUser)
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Profile Navigation Logic
    
    private func handleProfileTap() {
        // Check if this is the current user
        if let currentUser = authService.currentUser,
           currentUser.id == userId {
            // Don't open modal for current user
            print("👤 Tapped own username - user should use Profile tab")
            return
        }
        
        // Load other user's profile
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        guard profileUser == nil else {
            // Already loaded, just show the profile
            await MainActor.run {
                showOtherUserProfile = true
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
        }
        
        do {
            if let user = try await authService.getUserById(userId: userId) {
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            } else {
                // Fallback: create a minimal user
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                showOtherUserProfile = true
            }
        }
    }
    
    private func createMinimalUser() -> User {
        var user = User(
            id: userId,
            email: "\(username)@example.com",
            username: username,
            fullName: username.capitalized
        )
        
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0
        
        return user
    }
}

// MARK: - Clickable User Avatar

struct ClickableUserAvatar: View {
    let userId: String
    let username: String
    let size: CGFloat
    
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(userId: String, username: String, size: CGFloat = 40) {
        self.userId = userId
        self.username = username
        self.size = size
    }
    
    var body: some View {
        Button(action: {
            handleProfileTap()
        }) {
            ZStack {
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(username)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold.opacity(0.2))
                        .overlay(
                            Text(String(username.prefix(1)).uppercased())
                                .font(.system(size: size * 0.4, weight: .bold))
                                .foregroundColor(.arkadGold)
                        )
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                
                if isLoadingUser {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: size, height: size)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                OtherUserProfileView(user: profileUser)
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Profile Navigation Logic (Same as ClickableUsername)
    
    private func handleProfileTap() {
        if let currentUser = authService.currentUser,
           currentUser.id == userId {
            print("👤 Tapped own avatar - user should use Profile tab")
            return
        }
        
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        guard profileUser == nil else {
            await MainActor.run {
                showOtherUserProfile = true
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
        }
        
        do {
            if let user = try await authService.getUserById(userId: userId) {
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            } else {
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                showOtherUserProfile = true
            }
        }
    }
    
    private func createMinimalUser() -> User {
        var user = User(
            id: userId,
            email: "\(username)@example.com",
            username: username,
            fullName: username.capitalized
        )
        
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = 0.0
        user.winRate = 0.0
        
        return user
    }
}

#Preview {
    VStack(spacing: 20) {
        ClickableUsername(
            userId: "sample1",
            username: "trader123",
            font: .headline,
            color: .blue
        )
        
        ClickableUserAvatar(
            userId: "sample2", 
            username: "marktwo",
            size: 50
        )
    }
    .padding()
    .environmentObject(FirebaseAuthService.shared)
}