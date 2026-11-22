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

// MARK: - Enhanced Clickable User Avatar
struct ClickableUserAvatar: View {
    let userId: String
    let username: String
    let size: CGFloat
    let showOnlineStatus: Bool
    let showVerificationBadge: Bool
    
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    @State private var imageLoadError = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(
        userId: String,
        username: String,
        size: CGFloat = 40,
        showOnlineStatus: Bool = false,
        showVerificationBadge: Bool = true
    ) {
        self.userId = userId
        self.username = username
        self.size = size
        self.showOnlineStatus = showOnlineStatus
        self.showVerificationBadge = showVerificationBadge
    }
    
    var body: some View {
        Button(action: {
            handleProfileTap()
        }) {
            ZStack {
                // Main avatar image
                avatarImageView
                
                // Loading overlay
                if isLoadingUser {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: size, height: size)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                                .foregroundColor(.white)
                        )
                }
                
                // Online status indicator
                if showOnlineStatus && profileUser != nil {
                    Circle()
                        .fill(Color.green)
                        .frame(width: size * 0.25, height: size * 0.25)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: size * 0.35, y: size * 0.35)
                }
                
                // Verification badge
                if showVerificationBadge,
                   let profileUser = profileUser,
                   profileUser.isVerified {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.15, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: size * 0.35, y: -size * 0.35)
                }
            }
        }
        .buttonStyle(ClickableAvatarButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                UserProfileSheet(user: profileUser, community: nil)
                    .environmentObject(authService)
            }
        }
        .onAppear {
            // Pre-load user data for better UX
            if profileUser == nil {
                Task {
                    await preloadUserData()
                }
            }
        }
    }
    
    // MARK: - Avatar Image View
    @ViewBuilder
    private var avatarImageView: some View {
        Group {
            if let profileUser = profileUser,
               let profileImageUrl = profileUser.profileImageUrl,
               !profileImageUrl.isEmpty,
               !imageLoadError {
                
                AsyncImage(url: URL(string: profileImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [userColor.opacity(0.8), userColor.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: userColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    case .failure(_):
                        fallbackAvatarView
                            .onAppear {
                                imageLoadError = true
                            }
                    
                    case .empty:
                        Circle()
                            .fill(userColor.opacity(0.2))
                            .frame(width: size, height: size)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .foregroundColor(userColor)
                            )
                    
                    @unknown default:
                        fallbackAvatarView
                    }
                }
                
            } else {
                fallbackAvatarView
            }
        }
    }
    
    @ViewBuilder
    private var fallbackAvatarView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [userColor.opacity(0.8), userColor.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(userInitials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: userColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helper Properties
    private var userColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo, .teal, .red]
        let hash = userId.hashValue
        return colors[abs(hash) % colors.count]
    }
    
    private var userInitials: String {
        if let profileUser = profileUser {
            let names = profileUser.fullName.components(separatedBy: " ")
            if names.count >= 2 {
                return String(names[0].prefix(1)) + String(names[1].prefix(1))
            } else if let firstChar = names.first?.first {
                return String(firstChar)
            }
        }
        return String(username.prefix(2)).uppercased()
    }
    
    // MARK: - Profile Navigation Logic
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
    
    private func preloadUserData() async {
        guard profileUser == nil else { return }
        
        do {
            if let user = try await authService.getUserById(userId: userId) {
                await MainActor.run {
                    profileUser = user
                }
            }
        } catch {
            print("⚠️ Failed to preload user data: \(error)")
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

// MARK: - Enhanced Profile Row Component
struct UserProfileRow: View {
    let userId: String
    let username: String
    let fullName: String?
    let subtitle: String?
    let showTrailingInfo: Bool
    
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(
        userId: String,
        username: String,
        fullName: String? = nil,
        subtitle: String? = nil,
        showTrailingInfo: Bool = true
    ) {
        self.userId = userId
        self.username = username
        self.fullName = fullName
        self.subtitle = subtitle
        self.showTrailingInfo = showTrailingInfo
    }
    
    var body: some View {
        Button(action: {
            handleProfileTap()
        }) {
            HStack(spacing: 12) {
                // Avatar
                ClickableUserAvatar(
                    userId: userId,
                    username: username,
                    size: 44,
                    showOnlineStatus: true,
                    showVerificationBadge: true
                )
                .disabled(true) // Disable nested button
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(fullName ?? username.capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let profileUser = profileUser,
                           profileUser.subscriptionTier != .basic {
                            Text(profileUser.subscriptionTier.displayName.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(subscriptionTierColor(profileUser.subscriptionTier))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let subtitle = subtitle {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Trailing info
                if showTrailingInfo {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let profileUser = profileUser {
                            Text("\(Int(profileUser.winRate * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(profileUser.winRate > 0.6 ? .green : .orange)
                            
                            Text("Win Rate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if isLoadingUser {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                UserProfileSheet(user: profileUser, community: nil)
                    .environmentObject(authService)
            }
        }
        .task {
            await preloadUserData()
        }
    }
    
    private func subscriptionTierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .purple
        }
    }
    
    private func handleProfileTap() {
        if let currentUser = authService.currentUser,
           currentUser.id == userId {
            print("👤 Tapped own profile row - user should use Profile tab")
            return
        }
        
        Task {
            await loadUserProfile()
        }
    }
    
    private func preloadUserData() async {
        guard profileUser == nil else { return }
        
        do {
            if let user = try await authService.getUserById(userId: userId) {
                await MainActor.run {
                    profileUser = user
                }
            }
        } catch {
            print("⚠️ Failed to preload user data: \(error)")
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
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            await MainActor.run {
                isLoadingUser = false
            }
        }
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

struct ClickableAvatarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
