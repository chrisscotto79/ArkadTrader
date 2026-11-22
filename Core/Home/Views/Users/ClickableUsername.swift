//
//  ClickableUsername.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//

import SwiftUI

// MARK: - Clickable Username Component
struct ClickableUsername: View {
    let userId: String
    let username: String
    let font: Font
    let color: Color
    let showProfileImage: Bool
    let imageSize: CGFloat
    
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(
        userId: String,
        username: String,
        font: Font = .subheadline,
        color: Color = .primary,
        showProfileImage: Bool = false,
        imageSize: CGFloat = 24
    ) {
        self.userId = userId
        self.username = username
        self.font = font
        self.color = color
        self.showProfileImage = showProfileImage
        self.imageSize = imageSize
    }
    
    var body: some View {
        Button(action: {
            handleProfileTap()
        }) {
            HStack(spacing: 8) {
                // Optional profile image
                if showProfileImage {
                    profileImageView
                }
                
                // Username with loading indicator
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
        }
        .buttonStyle(ClickableUsernameButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                UserProfileSheet(user: profileUser, community: nil)
                    .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Profile Image View
    @ViewBuilder
    private var profileImageView: some View {
        Group {
            if let profileUser = profileUser,
               let profileImageUrl = profileUser.profileImageUrl,
               !profileImageUrl.isEmpty {
                
                AsyncImage(url: URL(string: profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(userColor.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                                .foregroundColor(userColor)
                        )
                }
                .frame(width: imageSize, height: imageSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                
            } else {
                // Fallback to initials
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [userColor.opacity(0.3), userColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: imageSize, height: imageSize)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: imageSize * 0.4, weight: .bold))
                            .foregroundColor(userColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(userColor.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - User Color Generator
    private var userColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal, .red]
        let hash = userId.hashValue
        return colors[abs(hash) % colors.count]
    }
    
    // MARK: - Profile Navigation Logic
    private func handleProfileTap() {
        // Check if this is the current user
        if let currentUser = authService.currentUser,
           currentUser.id == userId {
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

// MARK: - Button Styles
struct ClickableUsernameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
