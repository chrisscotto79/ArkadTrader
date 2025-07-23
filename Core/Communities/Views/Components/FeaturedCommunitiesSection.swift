//
//  FeaturedCommunitiesSection.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

// File: Core/Communities/Views/Components/FeaturedCommunitiesSection.swift
// Featured Communities Section Component

import SwiftUI

struct FeaturedCommunitiesSection: View {
    // MARK: - Properties
    let communities: [Community]
    let onCommunityTap: (Community) -> Void
    let onSeeAllTap: (() -> Void)?
    let maxFeaturedCount: Int
    
    @State private var isLoading = false
    
    // MARK: - Initializers
    init(
        communities: [Community],
        maxFeaturedCount: Int = 3,
        onCommunityTap: @escaping (Community) -> Void,
        onSeeAllTap: (() -> Void)? = nil
    ) {
        self.communities = communities
        self.maxFeaturedCount = maxFeaturedCount
        self.onCommunityTap = onCommunityTap
        self.onSeeAllTap = onSeeAllTap
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if communities.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    headerView
                    cardsScrollView
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Featured Communities")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Top communities by engagement")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if shouldShowSeeAllButton {
                seeAllButton
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var seeAllButton: some View {
        Button(action: {
            onSeeAllTap?()
        }) {
            HStack(spacing: 6) {
                Text("See All")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.blue)
        }
        .scaleEffect(0.95)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
    
    // MARK: - Cards Scroll View
    private var cardsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(featuredCommunities) { community in
                    featuredCommunityCard(community)
                        .frame(width: 180)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func featuredCommunityCard(_ community: Community) -> some View {
        NavigationLink(destination: CommunityDetailView(community: community)) {
            CommunityCard.featured(
                community: community,
                onTap: nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    
    // MARK: - Enhanced Featured Card (Alternative Layout)
    private func enhancedFeaturedCard(_ community: Community) -> some View {
        Button(action: { handleCommunityTap(community) }) {
            VStack(spacing: 0) {
                // Header with gradient background
                headerSection(for: community)
                
                // Content section
                contentSection(for: community)
                
                // Footer with stats
                footerSection(for: community)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [getCommunityColor(for: community).opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(FeaturedCardButtonStyle())
    }
    
    private func headerSection(for community: Community) -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    getCommunityColor(for: community).opacity(0.8),
                    getCommunityColor(for: community).opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack {
                // Community avatar
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(getInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(getCommunityColor(for: community))
                    )
                
                Spacer()
                
                // Privacy indicator
                privacyBadge(for: community)
            }
            .padding(16)
        }
        .frame(height: 80)
    }
    
    private func contentSection(for community: Community) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(community.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(community.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func footerSection(for community: Community) -> some View {
        HStack {
            // Member count
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .font(.caption2)
                    .foregroundColor(getCommunityColor(for: community))
                
                Text(formatMemberCount(community.memberCount))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Community type badge
            Text(community.type.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(getCommunityColor(for: community))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(getCommunityColor(for: community).opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func privacyBadge(for community: Community) -> some View {
        HStack(spacing: 4) {
            Image(systemName: community.isPrivate ? "lock.fill" : "globe")
                .font(.caption2)
            
            Text(community.isPrivate ? "Private" : "Public")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Helper Methods
    private func handleCommunityTap(_ community: Community) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Trigger callback
        onCommunityTap(community)
    }
    
    private var featuredCommunities: [Community] {
        return Array(communities.prefix(maxFeaturedCount))
    }
    
    private var shouldShowSeeAllButton: Bool {
        return communities.count > maxFeaturedCount && onSeeAllTap != nil
    }
    
    private func getInitials(from name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func formatMemberCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    private func getCommunityColor(for community: Community) -> Color {
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

// MARK: - Custom Button Style
struct FeaturedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Loading State Extension
extension FeaturedCommunitiesSection {
    static func loading(maxFeaturedCount: Int = 3) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header skeleton
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 20)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 160, height: 12)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Cards skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<maxFeaturedCount, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 140)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

// MARK: - Shimmer Effect
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 200 : -200)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Convenience Initializers
extension FeaturedCommunitiesSection {
    // Standard featured section
    static func standard(
        communities: [Community],
        onCommunityTap: @escaping (Community) -> Void,
        onSeeAllTap: (() -> Void)? = nil
    ) -> FeaturedCommunitiesSection {
        FeaturedCommunitiesSection(
            communities: communities,
            maxFeaturedCount: 3,
            onCommunityTap: onCommunityTap,
            onSeeAllTap: onSeeAllTap
        )
    }
    
    // Compact featured section (2 cards)
    static func compact(
        communities: [Community],
        onCommunityTap: @escaping (Community) -> Void
    ) -> FeaturedCommunitiesSection {
        FeaturedCommunitiesSection(
            communities: communities,
            maxFeaturedCount: 2,
            onCommunityTap: onCommunityTap,
            onSeeAllTap: nil
        )
    }
    
    // Extended featured section (5 cards)
    static func extended(
        communities: [Community],
        onCommunityTap: @escaping (Community) -> Void,
        onSeeAllTap: @escaping () -> Void
    ) -> FeaturedCommunitiesSection {
        FeaturedCommunitiesSection(
            communities: communities,
            maxFeaturedCount: 5,
            onCommunityTap: onCommunityTap,
            onSeeAllTap: onSeeAllTap
        )
    }
}

// MARK: - Preview
#Preview("Featured Section") {
    let sampleCommunities = [
        Community(
            name: "Day Traders Elite",
            description: "Advanced day trading strategies and live market analysis for experienced traders",
            type: .dayTrading,
            creatorId: "user1",
            memberCount: 1250,
            isPrivate: false
        ),
        Community(
            name: "Options Hub",
            description: "Options trading community for all skill levels and strategies",
            type: .options,
            creatorId: "user2",
            memberCount: 890,
            isPrivate: false
        ),
        Community(
            name: "Crypto Signals",
            description: "Real-time cryptocurrency trading signals and market insights",
            type: .crypto,
            creatorId: "user3",
            memberCount: 2100,
            isPrivate: true
        )
    ]
    
    VStack(spacing: 30) {
        FeaturedCommunitiesSection.standard(
            communities: sampleCommunities,
            onCommunityTap: { community in
                print("Tapped: \(community.name)")
            },
            onSeeAllTap: {
                print("See all tapped")
            }
        )
        
        FeaturedCommunitiesSection.loading()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
