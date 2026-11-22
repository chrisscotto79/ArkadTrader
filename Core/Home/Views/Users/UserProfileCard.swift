//
//  UserProfileCard.swift
//  ArkadTrader
//
//  Updated with navigation to other user profiles and real profile images
//

import SwiftUI

struct UserProfileCard: View {
    let user: User
    @State private var isFollowing = false
    @State private var showOtherUserProfile = false
    @State private var imageLoadError = false
    @State private var isImageLoading = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        Button(action: {
            handleProfileCardTap()
        }) {
            VStack(spacing: 16) {
                // Profile header
                HStack(spacing: 16) {
                    // Enhanced profile image
                    profileImageView
                    
                    // User info section
                    VStack(alignment: .leading, spacing: 6) {
                        // Name and verification
                        HStack(spacing: 6) {
                            Text(user.fullName)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        
                        // Username
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Subscription tier badge
                        HStack(spacing: 8) {
                            subscriptionTierBadge
                            
                            // Win rate indicator
                            if user.winRate > 0 {
                                winRateBadge
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Follow button section
                    VStack(spacing: 8) {
                        followButtonView
                        
                        // Online status indicator (placeholder for future feature)
                        if shouldShowOnlineStatus {
                            onlineStatusIndicator
                        }
                    }
                }
                
                // Bio section
                if let bio = user.bio, !bio.isEmpty {
                    bioSectionView(bio)
                }
                
                // Enhanced stats section
                statsHorizontalView
            }
            .padding(20)
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(UserProfileCardButtonStyle())
        .sheet(isPresented: $showOtherUserProfile) {
            UserProfileSheet(user: user, community: nil)
                .environmentObject(authService)
        }
    }
    
    // MARK: - Profile Image View
    @ViewBuilder
    private var profileImageView: some View {
        ZStack {
            // Main profile image
            Group {
                if let profileImageUrl = user.profileImageUrl,
                   !profileImageUrl.isEmpty,
                   !imageLoadError {
                    
                    AsyncImage(url: URL(string: profileImageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [tierColor.opacity(0.8), tierColor.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                )
                                .shadow(color: tierColor.opacity(0.3), radius: 6, x: 0, y: 3)
                                .onAppear {
                                    isImageLoading = false
                                }
                        
                        case .failure(_):
                            fallbackAvatarView
                                .onAppear {
                                    imageLoadError = true
                                    isImageLoading = false
                                }
                        
                        case .empty:
                            loadingAvatarView
                                .onAppear {
                                    isImageLoading = true
                                }
                        
                        @unknown default:
                            fallbackAvatarView
                        }
                    }
                    
                } else {
                    fallbackAvatarView
                }
            }
            
            // Subscription tier corner badge
            if user.subscriptionTier != .basic {
                subscriptionCornerBadge
            }
        }
    }
    
    @ViewBuilder
    private var fallbackAvatarView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [tierColor.opacity(0.8), tierColor.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 70, height: 70)
            .overlay(
                Text(userInitials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: tierColor.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    @ViewBuilder
    private var loadingAvatarView: some View {
        Circle()
            .fill(tierColor.opacity(0.2))
            .frame(width: 70, height: 70)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: tierColor))
                    .scaleEffect(0.8)
            )
            .overlay(
                Circle()
                    .stroke(tierColor.opacity(0.3), lineWidth: 2)
            )
    }
    
    @ViewBuilder
    private var subscriptionCornerBadge: some View {
        Circle()
            .fill(tierColor)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: tierIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .offset(x: 25, y: -25)
    }
    
    // MARK: - Subscription Tier Badge
    @ViewBuilder
    private var subscriptionTierBadge: some View {
        Text(user.subscriptionTier.displayName.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tierColor)
                    .shadow(color: tierColor.opacity(0.5), radius: 3, x: 0, y: 1)
            )
    }
    
    // MARK: - Win Rate Badge
    @ViewBuilder
    private var winRateBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: winRateIcon)
                .font(.caption2)
                .foregroundColor(winRateColor)
            
            Text("\(Int(user.winRate * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(winRateColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(winRateColor.opacity(0.1))
        )
    }
    
    // MARK: - Follow Button
    @ViewBuilder
    private var followButtonView: some View {
        Button(action: {
            handleFollowTap()
        }) {
            HStack(spacing: 4) {
                Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(isFollowing ? "Unfollow" : "Follow")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isFollowing ? .primary : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isFollowing ? Color(.systemGray5) : tierColor)
                    .shadow(color: isFollowing ? .clear : tierColor.opacity(0.4), radius: 3, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Online Status
    @ViewBuilder
    private var onlineStatusIndicator: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            Text("Online")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Bio Section
    @ViewBuilder
    private func bioSectionView(_ bio: String) -> some View {
        Text(bio)
            .font(.subheadline)
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
    
    // MARK: - Enhanced Stats View
    @ViewBuilder
    private var statsHorizontalView: some View {
        HStack(spacing: 0) {
            // Followers
            statItemView(
                title: "Followers",
                value: "\(user.followersCount ?? 0)",
                color: .blue
            )
            
            Divider()
                .frame(height: 30)
                .background(Color(.systemGray4))
            
            // Following
            statItemView(
                title: "Following",
                value: "\(user.followingCount ?? 0)",
                color: .purple
            )
            
            Divider()
                .frame(height: 30)
                .background(Color(.systemGray4))
            
            // P&L
            statItemView(
                title: "Total P&L",
                value: user.totalProfitLoss.asCurrency,
                color: user.totalProfitLoss >= 0 ? .green : .red
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
    
    @ViewBuilder
    private func statItemView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Properties
    private var userInitials: String {
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
    
    private var tierColor: Color {
        switch user.subscriptionTier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return Color.orange // Using orange instead of .arkadGold for compatibility
        }
    }
    
    private var tierIcon: String {
        switch user.subscriptionTier {
        case .basic: return "person"
        case .pro: return "star"
        case .elite: return "crown"
        }
    }
    
    private var winRateColor: Color {
        switch user.winRate {
        case 0.8...: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private var winRateIcon: String {
        switch user.winRate {
        case 0.8...: return "arrow.up.circle.fill"
        case 0.6..<0.8: return "arrow.up.circle"
        case 0.4..<0.6: return "minus.circle"
        default: return "arrow.down.circle"
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
    }
    
    private var shadowColor: Color {
        Color.black.opacity(0.08)
    }
    
    private var borderColor: Color {
        tierColor.opacity(0.1)
    }
    
    private var shouldShowOnlineStatus: Bool {
        // Placeholder for online status feature
        // You can implement real online status logic here
        false
    }
    
    // MARK: - Action Handlers
    private func handleProfileCardTap() {
        // Check if this is the current user
        if let currentUser = authService.currentUser,
           currentUser.id == user.id {
            print("👤 Tapped own profile card - user should use Profile tab")
            return
        }
        
        showOtherUserProfile = true
    }
    
    private func handleFollowTap() {
        // Prevent card navigation when follow button is tapped
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isFollowing.toggle()
        }
        
        // TODO: Implement actual follow/unfollow logic with Firebase
        print("🔄 \(isFollowing ? "Following" : "Unfollowing") user: \(user.username)")
    }
}

// MARK: - Custom Button Style
struct UserProfileCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Extensions for Currency Formatting
