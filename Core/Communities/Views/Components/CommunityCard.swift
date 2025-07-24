// File: Core/Communities/Views/Components/CommunityCard.swift
// UPDATED: Fixed NavigationLink compatibility

import SwiftUI

struct CommunityCard: View {
    // MARK: - Properties
    let community: Community
    let onTap: (() -> Void)?
    let onJoinTap: (() -> Void)?
    let showJoinButton: Bool
    let showOwnerBadge: Bool
    let isUserMember: Bool
    let cardStyle: CardStyle
    
    @State private var isPressed = false
    @State private var isJoining = false
    
    // MARK: - Initializers
    init(
        community: Community,
        onTap: (() -> Void)? = nil,
        onJoinTap: (() -> Void)? = nil,
        showJoinButton: Bool = true,
        showOwnerBadge: Bool = false,
        isUserMember: Bool = false,
        cardStyle: CardStyle = .regular
    ) {
        self.community = community
        self.onTap = onTap
        self.onJoinTap = onJoinTap
        self.showJoinButton = showJoinButton
        self.showOwnerBadge = showOwnerBadge
        self.isUserMember = isUserMember
        self.cardStyle = cardStyle
    }
    
    // MARK: - Body
    var body: some View {
        // 🔧 FIX: Only wrap in Button if onTap is provided
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // 🔧 FIX: Just show content without Button wrapper for NavigationLink
                cardContent
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Card Content
    private var cardContent: some View {
        Group {
            switch cardStyle {
            case .regular:
                regularCardLayout
            case .featured:
                featuredCardLayout
            case .compact:
                compactCardLayout
            }
        }
    }
    
    // MARK: - Regular Card Layout
    private var regularCardLayout: some View {
        HStack(spacing: 16) {
            // Community Avatar
            communityAvatar(size: 56)
            
            // Community Info
            VStack(alignment: .leading, spacing: 6) {
                // Title Row
                titleRow
                
                // Description
                Text(community.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Stats Row
                statsRow
            }
            
            Spacer()
            
            // Action Button
            actionButton
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isPressed ? Color.blue.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Featured Card Layout
    private var featuredCardLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                communityAvatar(size: 44)
                
                Spacer()
                
                privacyIndicator
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(community.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(community.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(formatMemberCount(community.memberCount))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    featuredBadge
                }
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: 180, height: 140)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(getCommunityColor().opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Compact Card Layout
    private var compactCardLayout: some View {
        HStack(spacing: 12) {
            communityAvatar(size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(community.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if community.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                Text("\(formatMemberCount(community.memberCount)) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isUserMember {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Supporting Views
    private func communityAvatar(size: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [getCommunityColor(), getCommunityColor().opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(getInitials())
                    .font(size > 50 ? .title2 : size > 40 ? .headline : .caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
            .shadow(color: getCommunityColor().opacity(0.3), radius: size > 50 ? 6 : 3, x: 0, y: 2)
    }
    
    private var titleRow: some View {
        HStack {
            Text(community.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if showOwnerBadge {
                ownerBadge
            }
            
            if community.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var statsRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(getCommunityColor())
                
                Text("\(formatMemberCount(community.memberCount)) members")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            communityTypeBadge
            
            Spacer()
        }
    }
    
    private var actionButton: some View {
        Group {
            if showJoinButton && !isUserMember {
                joinButton
            } else if isUserMember {
                memberIndicator
            } else {
                EmptyView()
            }
        }
    }
    
    private var joinButton: some View {
        Button(action: {
            handleJoinAction()
        }) {
            HStack(spacing: 6) {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: community.isPrivate ? "envelope.fill" : "plus")
                        .font(.caption)
                }
                
                Text(community.isPrivate ? "Request" : "Join")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(getCommunityColor())
            .cornerRadius(16)
            .shadow(color: getCommunityColor().opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .disabled(isJoining)
        .scaleEffect(isJoining ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isJoining)
    }
    
    private var memberIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.green)
            
            Text("Member")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var ownerBadge: some View {
        Text("OWNER")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(4)
    }
    
    private var communityTypeBadge: some View {
        Text(community.type.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(getCommunityColor())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(getCommunityColor().opacity(0.15))
            .cornerRadius(8)
    }
    
    private var featuredBadge: some View {
        Text("Featured")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(6)
    }
    
    private var privacyIndicator: some View {
        Image(systemName: community.isPrivate ? "lock.fill" : "globe")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Helper Methods
    private func handleJoinAction() {
        guard let onJoinTap = onJoinTap else { return }
        
        isJoining = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Simulate join delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onJoinTap()
            isJoining = false
        }
    }
    
    private func getInitials() -> String {
        let words = community.name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(community.name.prefix(2)).uppercased()
        }
    }
    
    private func formatMemberCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    private func getCommunityColor() -> Color {
        switch community.type {
        case .dayTrading: return .red
        case .swingTrading: return .orange
        case .options: return .purple
        case .crypto: return .yellow
        case .stocks: return .green
        case .general: return .blue
        }
    }
}

// MARK: - Card Styles
extension CommunityCard {
    enum CardStyle {
        case regular    // Full-width card with all details
        case featured   // Square card for featured section
        case compact    // Minimal card for lists
    }
}

// MARK: - Convenience Initializers
extension CommunityCard {
    // For regular community listings
    static func regular(
        community: Community,
        isUserMember: Bool = false,
        onTap: (() -> Void)? = nil,
        onJoin: (() -> Void)? = nil
    ) -> CommunityCard {
        CommunityCard(
            community: community,
            onTap: onTap,
            onJoinTap: onJoin,
            showJoinButton: true,
            showOwnerBadge: false,
            isUserMember: isUserMember,
            cardStyle: .regular
        )
    }
    
    // For featured community sections
    static func featured(
        community: Community,
        onTap: (() -> Void)? = nil
    ) -> CommunityCard {
        CommunityCard(
            community: community,
            onTap: onTap,
            onJoinTap: nil,
            showJoinButton: false,
            showOwnerBadge: false,
            isUserMember: false,
            cardStyle: .featured
        )
    }
    
    // 🔧 FIX: Updated userCommunity to work with NavigationLink (onTap = nil)
    static func userCommunity(
        community: Community,
        isOwner: Bool = false,
        onTap: (() -> Void)? = nil
    ) -> CommunityCard {
        CommunityCard(
            community: community,
            onTap: onTap, // This will be nil for NavigationLink usage
            onJoinTap: nil,
            showJoinButton: false,
            showOwnerBadge: isOwner,
            isUserMember: true,
            cardStyle: .regular
        )
    }
    
    // For compact lists
    static func compact(
        community: Community,
        isUserMember: Bool = false,
        onTap: (() -> Void)? = nil
    ) -> CommunityCard {
        CommunityCard(
            community: community,
            onTap: onTap,
            onJoinTap: nil,
            showJoinButton: false,
            showOwnerBadge: false,
            isUserMember: isUserMember,
            cardStyle: .compact
        )
    }
}

// MARK: - Preview
#Preview("Regular Card") {
    VStack(spacing: 16) {
        CommunityCard.regular(
            community: Community(
                name: "Day Traders Elite",
                description: "Advanced day trading strategies and live market analysis for experienced traders looking to improve their skills",
                type: .dayTrading,
                creatorId: "test-user",
                memberCount: 1250,
                isPrivate: false
            ),
            onTap: { print("Tapped community") },
            onJoin: { print("Joined community") }
        )
        
        CommunityCard.featured(
            community: Community(
                name: "Crypto Signals",
                description: "Real-time cryptocurrency trading signals and market insights",
                type: .crypto,
                creatorId: "test-user",
                memberCount: 2100,
                isPrivate: false
            ),
            onTap: { print("Featured tapped") }
        )
        
        CommunityCard.userCommunity(
            community: Community(
                name: "My Trading Community",
                description: "My personal trading community for sharing insights",
                type: .options,
                creatorId: "current-user",
                memberCount: 45,
                isPrivate: true
            ),
            isOwner: true,
            onTap: nil // This allows NavigationLink to work
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
