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
    @State private var showJoinConfirmation = false
    @State private var isJoining = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with banner and profile
                    headerSection
                    
                    // Content sections
                    VStack(spacing: 24) {
                        // Basic info section
                        basicInfoSection
                        
                        // Stats section
                        statsSection
                        
                        // Description section
                        descriptionSection
                        
                        // Activity section
                        activitySection
                        
                        // Members preview section
                        membersPreviewSection
                        
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
        .alert("Join Community", isPresented: $showJoinConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(community.isPrivate ? "Send Request" : "Join") {
                joinCommunity()
            }
        } message: {
            Text(community.isPrivate ? 
                "Your request will be sent to the community admins for approval." :
                "Are you sure you want to join \(community.name)?")
        }
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
                
                if let profileUrl = community.profileImageUrl, !profileUrl.isEmpty {
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
    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            // Add some top padding to account for profile overlap
            Rectangle()
                .fill(Color.clear)
                .frame(height: 30)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Community")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)
                        .textCase(.uppercase)
                    
                    Text(community.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }
                
                Spacer()
                
                // Activity indicator
                activityIndicator
            }
        }
    }
    
    private var activityIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(getActivityColor())
                .frame(width: 8, height: 8)
            
            Text(community.calculatedActivityLevel.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.backgroundSecondary)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.borderPrimary.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
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
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundColor(getActivityColor())
                
                Text("Activity Level")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text(community.calculatedActivityLevel.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(getActivityColor())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(getActivityColor().opacity(0.1))
                    )
            }
            
            Text(getActivityDescription())
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .lineSpacing(2)
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
    
    private var membersPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16))
                    .foregroundColor(getCommunityColor())
                
                Text("Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text("\(community.memberCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)
            }
            
            // Member avatars if available
            if !community.memberAvatars.isEmpty {
                memberAvatarStack
            } else {
                Text("Join to see community members")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .italic()
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
    
    private var memberAvatarStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(community.memberAvatars.prefix(5).enumerated()), id: \.offset) { index, avatarUrl in
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.backgroundSecondary, lineWidth: 2)
                )
                .zIndex(Double(5 - index))
            }
            
            if community.memberAvatars.count > 5 {
                Text("+\(community.memberAvatars.count - 5)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)
                    .padding(.leading, 12)
            }
            
            Spacer()
        }
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
                    featureRow(icon: "globe", text: "Public community")
                } else {
                    featureRow(icon: "lock.fill", text: "Private, approval required")
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
                // Join/Request Button
                Button(action: {
                    if community.isPrivate {
                        showJoinConfirmation = true
                    } else {
                        joinCommunity()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isJoining {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: community.isPrivate ? "lock.fill" : "person.badge.plus")
                                .font(.system(size: 18))
                        }
                        
                        Text(isJoining ? "Joining..." : (community.isPrivate ? "Request to Join" : "Join Community"))
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
        
        // Add a slight delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onJoin()
            isJoining = false
            
            // Show success and auto-dismiss after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
    
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
    
    private func getActivityDescription() -> String {
        switch community.calculatedActivityLevel {
        case .low:
            return "This community has light activity with occasional discussions and updates."
        case .medium:
            return "This community has regular activity with daily discussions and member engagement."
        case .high:
            return "This community is very active with frequent discussions, callouts, and member participation."
        }
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