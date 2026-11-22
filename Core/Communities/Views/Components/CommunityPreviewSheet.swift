//
//  CommunityPreviewSheet.swift
//  ArkadTrader
//
//  Created by chris scotto on 8/12/25.
//


// File: Core/Communities/Views/Components/CommunityPreviewSheet.swift
// Community Preview Sheet for quick community overview

import SwiftUI

struct CommunityPreviewSheet: View {
    let community: Community
    let isUserMember: Bool
    let onJoin: () -> Void
    let onEnterCommunity: () -> Void
    let onClose: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isJoining = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with banner and profile
                    headerSection
                    
                    // Content sections
                    VStack(spacing: 24) {
                        // Room for the avatar that overlaps the banner
                        Color.clear.frame(height: 30)
                        
                        // Stats section
                        statsSection
                        
                        // Description section
                        descriptionSection
                        
                        // Community features section
                        featuresSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for floating button
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) {
                floatingActionButton
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
            // Banner background
            bannerBackground
                .frame(height: 200)
            
            // Close button
            closeButton
                .padding(16)
            
            // Profile image and basic info overlay
            VStack {
                Spacer()
                profileAndBasicInfo
                    .padding(.horizontal, 20)
                    .offset(y: 30) // Overlap with content
            }
        }
    }
    
    private var bannerBackground: some View {
        Group {
            if let bannerUrl = community.bannerURL, !bannerUrl.isEmpty {
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
        .overlay(
            // Dark overlay for better text readability
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipped()
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
    }
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
                
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private var profileAndBasicInfo: some View {
        HStack(spacing: 16) {
            // Community profile image
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                if let profileUrl = community.avatarURL, !profileUrl.isEmpty {
                    AsyncImage(url: URL(string: profileUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                    } placeholder: {
                        defaultProfileImage
                    }
                } else {
                    defaultProfileImage
                }
                
                // Member indicator
                if isUserMember {
                    Circle()
                        .fill(Color.marketGreen)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 28, y: 28)
                }
            }
            
            // Name and type
            VStack(alignment: .leading, spacing: 8) {
                Text(community.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                HStack(spacing: 8) {
                    // Type badge
                    Text(community.type.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                        )
                    
                    // Privacy badge
                    if community.isPrivate {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text("Private")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                        )
                    }
                }
            }
            
            Spacer()
        }
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
            .frame(width: 76, height: 76)
            .overlay(
                Text(community.initials)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Content Sections
    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(community.memberCount)",
                label: "Members",
                icon: "person.3.fill"
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                value: formatDate(community.createdAt),
                label: "Created",
                icon: "calendar"
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                value: community.lastActivityText,
                label: "Activity",
                icon: "chart.line.uptrend.xyaxis"
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(getCommunityColor())
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            Text(community.description.isEmpty ? "No description available." : community.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.arkadGold)
                
                Text("Community Features")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
            }
            
            VStack(spacing: 8) {
                featureRow(icon: "bubble.left.and.bubble.right.fill", text: "Text channels for discussions")
                featureRow(icon: "megaphone.fill", text: "Trading callouts and signals")
                featureRow(icon: "chart.bar.fill", text: "Performance leaderboards")
                if !community.isPrivate {
                    featureRow(icon: "globe", text: "Public, listed in Discover")
                } else {
                    featureRow(icon: "lock.fill", text: "Private, hidden from Discover")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(getCommunityColor())
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack(spacing: 12) {
            if isUserMember {
                // Enter Community Button
                Button(action: {
                    onEnterCommunity()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                        
                        Text("Enter Community")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [getCommunityColor(), getCommunityColor().opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: getCommunityColor().opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isJoining)
            } else {
                // Join Button
                Button(action: joinCommunity) {
                    HStack(spacing: 8) {
                        if isJoining {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18))
                        }
                        
                        Text(isJoining ? "Joining..." : "Join Community")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.arkadGold, Color.arkadGold.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isJoining)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            // Gradient overlay to separate from content
            LinearGradient(
                colors: [Color.clear, Color.backgroundPrimary.opacity(0.8), Color.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Methods
    private func joinCommunity() {
        isJoining = true
        onJoin()
        dismiss()
    }
    
    private func getCommunityColor() -> Color {
        community.type.tint
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    let sampleCommunity = Community(
        name: "Crypto Elite Traders",
        description: "Advanced cryptocurrency trading community focused on technical analysis, market trends, and profitable trading strategies. We share insights, discuss market movements, and help each other grow as traders.",
        type: .crypto,
        creatorId: "user123",
        memberCount: 1247,
        isPrivate: false
    )
    
    CommunityPreviewSheet(
        community: sampleCommunity,
        isUserMember: false,
        onJoin: {
            print("Join tapped")
        },
        onEnterCommunity: {
            print("Enter community tapped")
        },
        onClose: {
            print("Close tapped")
        }
    )
}
