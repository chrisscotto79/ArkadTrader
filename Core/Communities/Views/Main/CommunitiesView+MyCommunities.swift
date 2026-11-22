// File: Core/Communities/Views/Main/CommunitiesView+MyCommunities.swift
// The My Communities tab.

import SwiftUI

// MARK: - My Communities Content
extension CommunitiesView {
    var myCommunitiesContent: some View {
        VStack(spacing: 28) {
            if viewModel.userCommunities.isEmpty {
                emptyMyCommunitiesState
            } else {
                VStack(spacing: 36) {
                    if !viewModel.userOwnedCommunities.isEmpty {
                        communitySection(
                            title: "Communities I Own",
                            communities: viewModel.userOwnedCommunities,
                            isOwner: true
                        )
                    }
                    
                    if !viewModel.userMemberCommunities.isEmpty {
                        communitySection(
                            title: "Communities I'm In",
                            communities: viewModel.userMemberCommunities,
                            isOwner: false
                        )
                    }
                }
            }
        }
    }
    
    func communitySection(title: String, communities: [Community], isOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Enhanced section header
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                // Count badge
                Text("\(communities.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.arkadGold)
                    .frame(minWidth: 24)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.arkadGold.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.arkadGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                
                Spacer()
                
                if isOwner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.arkadGold)
                        .opacity(0.6)
                }
            }
            
            // Community cards with enhanced design
            LazyVStack(spacing: 14) {
                ForEach(communities) { community in
                    communityCard(community: community, isOwner: isOwner)
                }
            }
        }
    }
    
    func communityCard(community: Community, isOwner: Bool) -> some View {
        Button(action: {
            navigateToCommunitDetail(community)
        }) {
            HStack(spacing: 18) {
                // Enhanced avatar with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getCommunityColor(for: community.type),
                                    getCommunityColor(for: community.type).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: getCommunityColor(for: community.type).opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(getCommunityInitials(from: community.name))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Enhanced info section
                VStack(alignment: .leading, spacing: 6) {
                    Text(community.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 14) {
                        // Members with icon
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.textSecondary)
                            
                            Text("\(community.memberCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .fixedSize()
                        
                        if isOwner {
                            // Owner badge
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11))
                                
                                Text("Owner")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .fixedSize()
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.arkadGold.opacity(0.1))
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Enhanced type badge and chevron
                HStack(spacing: 12) {
                    Text(community.type.shortDisplayName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundColor(getCommunityColor(for: community.type))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(getCommunityColor(for: community.type).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            getCommunityColor(for: community.type).opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                        )
                    
                    // Animated chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textTertiary)
                        .opacity(0.6)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.borderPrimary.opacity(0.3), Color.borderPrimary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
