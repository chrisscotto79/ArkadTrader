// File: Core/Communities/Views/Components/EnhancedCommunityCard.swift
// New Enhanced Vertical Community Card with Banner, Profile Image, and Activity

import SwiftUI

struct EnhancedCommunityCard: View {
    let community: Community
    let style: CardStyle
    let isUserMember: Bool
    let onTap: () -> Void
    let onJoin: () -> Void
    let onInfo: () -> Void
    
    @State private var isPressed = false
    
    enum CardStyle {
        case featured(width: CGFloat = 280, height: CGFloat = 320)
        case regular(width: CGFloat = 160, height: CGFloat = 240)
        case large(width: CGFloat = 200, height: CGFloat = 280)
        
        var width: CGFloat {
            switch self {
            case .featured(let width, _): return width
            case .regular(let width, _): return width
            case .large(let width, _): return width
            }
        }
        
        var height: CGFloat {
            switch self {
            case .featured(_, let height): return height
            case .regular(_, let height): return height
            case .large(_, let height): return height
            }
        }
        
        var isFeatured: Bool {
            if case .featured = self { return true }
            return false
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Banner Section
                bannerSection
                    .frame(height: style.height * 0.35)
                
                // Content Section
                contentSection
                    .frame(height: style.height * 0.65)
            }
            .frame(width: style.width, height: style.height)
            .background(
                RoundedRectangle(cornerRadius: style.isFeatured ? 20 : 16)
                    .fill(Color.backgroundSecondary)
                    .shadow(
                        color: .black.opacity(isPressed ? 0.15 : 0.08),
                        radius: isPressed ? 20 : 12,
                        x: 0,
                        y: isPressed ? 8 : 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.isFeatured ? 20 : 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.borderPrimary.opacity(0.3), Color.borderPrimary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    // MARK: - Banner Section
    private var bannerSection: some View {
        ZStack(alignment: .topTrailing) {
            // Banner Background
            Group {
                if let bannerUrl = community.bannerImageUrl, !bannerUrl.isEmpty {
                    AsyncImage(url: URL(string: bannerUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        defaultBannerGradient
                    }
                } else {
                    defaultBannerGradient
                }
            }
            .clipped()
            
            // Overlay gradient for better text readability
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Top badges
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    
                    // Featured badge for featured cards
                    if style.isFeatured {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.arkadGold)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    
                    // Info button
                    Button(action: onInfo) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "info")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                
                Spacer()
                
                // Activity indicator
                HStack {
                    Spacer()
                    activityIndicator
                }
            }
            .padding(12)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: style.isFeatured ? 20 : 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: style.isFeatured ? 20 : 16
            )
        )
    }
    
    private var defaultBannerGradient: some View {
        LinearGradient(
            colors: [
                getCommunityColor(),
                getCommunityColor().opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle pattern overlay
            GeometryReader { geometry in
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 20...60))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 1)
                }
            }
        )
    }
    
    private var activityIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(getActivityColor())
                .frame(width: 6, height: 6)
            
            Text(community.calculatedActivityLevel.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.4))
        )
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 0) {
            // Profile and basic info
            profileSection
                .padding(.top, -20) // Overlap with banner
            
            // Community details
            VStack(alignment: .leading, spacing: style.isFeatured ? 12 : 8) {
                // Name and type
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.system(size: style.isFeatured ? 17 : 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(style.isFeatured ? 2 : 1)
                        .multilineTextAlignment(.leading)
                    
                    if style.isFeatured {
                        Text(community.description)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // Stats row
                statsRow
                
                Spacer()
                
                // Action button
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private var profileSection: some View {
        HStack(spacing: 12) {
            // Community profile image
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                
                if let profileUrl = community.profileImageUrl, !profileUrl.isEmpty {
                    AsyncImage(url: URL(string: profileUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } placeholder: {
                        defaultProfileImage
                    }
                } else {
                    defaultProfileImage
                }
                
                // Member status indicator
                if isUserMember {
                    Circle()
                        .fill(Color.marketGreen)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 18, y: 18)
                }
            }
            
            // Type badge and member avatars
            VStack(alignment: .leading, spacing: 6) {
                // Type badge
                Text(community.type.shortDisplayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(getCommunityColor())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(getCommunityColor().opacity(0.1))
                            .overlay(
                                Capsule()
                                    .strokeBorder(getCommunityColor().opacity(0.3), lineWidth: 1)
                            )
                    )
                
                // Member avatars (if available)
                if !community.memberAvatars.isEmpty && style.isFeatured {
                    memberAvatarStack
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private var defaultProfileImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [getCommunityColor(), getCommunityColor().opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 46, height: 46)
            .overlay(
                Text(community.initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private var memberAvatarStack: some View {
        HStack(spacing: -6) {
            ForEach(Array(community.memberAvatars.prefix(3).enumerated()), id: \.offset) { index, avatarUrl in
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .zIndex(Double(3 - index))
            }
            
            if community.memberAvatars.count > 3 {
                Text("+\(community.memberAvatars.count - 3)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .padding(.leading, 4)
            }
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: style.isFeatured ? 12 : 8) {
            // Member count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                
                Text("\(community.memberCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            
            if style.isFeatured && community.isRecentlyActive {
                // Activity indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.marketGreen)
                        .frame(width: 4, height: 4)
                    
                    Text(community.lastActivityText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.marketGreen)
                }
            }
            
            Spacer()
            
            // Privacy indicator
            if community.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
        }
    }
    
    private var actionButton: some View {
        Group {
            if isUserMember {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    
                    Text("Member")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.marketGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, style.isFeatured ? 12 : 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.marketGreen.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.marketGreen.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                Button(action: onJoin) {
                    HStack(spacing: 6) {
                        Image(systemName: community.isPrivate ? "lock.fill" : "person.badge.plus")
                            .font(.system(size: 14))
                        
                        Text(community.isPrivate ? "Request" : "Join")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, style.isFeatured ? 12 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .arkadGold.opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCommunityColor() -> Color {
        switch community.type {
        case .dayTrading: return .marketRed
        case .swingTrading: return .warning
        case .options: return .optionColor
        case .crypto: return .cryptoColor
        case .stocks: return .stockColor
        case .general: return .arkadGold
        }
    }
    
    private func getActivityColor() -> Color {
        switch community.calculatedActivityLevel {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .marketGreen
        }
    }
}

// MARK: - Backward Compatible CommunityCard
struct CommunityCard: View {
    let community: Community
    let isUserMember: Bool
    let onTap: () -> Void
    let onJoin: () -> Void
    
    var body: some View {
        EnhancedCommunityCard(
            community: community,
            style: .regular(),
            isUserMember: isUserMember,
            onTap: onTap,
            onJoin: onJoin,
            onInfo: {
                // Default empty action for info button
            }
        )
    }
}

// MARK: - Backward Compatible CommunityCard


// MARK: - Helper Functions for Backward Compatibility
func featuredCommunityCard(
    community: Community,
    isUserMember: Bool = false,
    onTap: @escaping () -> Void = {},
    onJoin: @escaping () -> Void = {}
) -> some View {
    EnhancedCommunityCard(
        community: community,
        style: .featured(),
        isUserMember: isUserMember,
        onTap: onTap,
        onJoin: onJoin,
        onInfo: {}
    )
}



// MARK: - Custom Shape for Rounded Corners (for backward compatibility)
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    let sampleCommunity = Community(
        name: "Crypto Traders",
        description: "Advanced cryptocurrency trading strategies and market analysis",
        type: .crypto,
        creatorId: "user123",
        memberCount: 247,
        isPrivate: false
    )
    
    VStack(spacing: 20) {
        // Featured style
        EnhancedCommunityCard(
            community: sampleCommunity,
            style: .featured(),
            isUserMember: false,
            onTap: {},
            onJoin: {},
            onInfo: {}
        )
        
        HStack(spacing: 16) {
            // Regular style
            EnhancedCommunityCard(
                community: sampleCommunity,
                style: .regular(),
                isUserMember: true,
                onTap: {},
                onJoin: {},
                onInfo: {}
            )
            
            EnhancedCommunityCard(
                community: sampleCommunity,
                style: .regular(),
                isUserMember: false,
                onTap: {},
                onJoin: {},
                onInfo: {}
            )
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
