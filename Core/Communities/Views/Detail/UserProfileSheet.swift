// File: Core/Communities/Views/Detail/UserProfileSheet.swift
// Profile sheet opened from a username or avatar in chat and the feed.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FirebaseStorage
import Photos
import MobileCoreServices

// MARK: - Enhanced User Profile Sheet (Moved from nested scope)
struct UserProfileSheet: View {
    let user: User
    let community: Community?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: FirebaseAuthService
    
    @State private var isFollowing = false
    @State private var showingMessageComposer = false
    @State private var showingMoreOptions = false
    @State private var animateContent = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with Background
                    headerWithBackground
                    
                    // Profile Content
                    VStack(spacing: 24) {
                        // Stats Grid
                        enhancedStatsSection
                        
                        // Bio Section
                        if let bio = user.bio, !bio.isEmpty {
                            bioSection(bio)
                        }
                        
                        // Trading Performance Section
                        tradingPerformanceSection
                        
                        // Communities Section
                        communitiesSection
                        
                        // Recent Activity Section
                        recentActivitySection
                        
                        // Action Buttons
                        if user.id != authService.currentUser?.id {
                            actionButtonsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if user.id != authService.currentUser?.id {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingMoreOptions = true }) {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
        .confirmationDialog("User Options", isPresented: $showingMoreOptions) {
            Button("Report User") {
                // Handle report
            }
            Button("Block User") {
                // Handle block
            }
            Button("Share Profile") {
                // Handle share
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Header with Background
    private var headerWithBackground: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    subscriptionTierColor(user.subscriptionTier).opacity(0.3),
                    subscriptionTierColor(user.subscriptionTier).opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .frame(height: 280)
            
            VStack(spacing: 20) {
                Spacer().frame(height: 60)
                
                // ENHANCED: Profile Image (same style as chat)
                profileImageView
                
                // Name and Username
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.accentColor)
                                .font(.title3)
                        }
                        
                        if user.subscriptionTier != .basic {
                            subscriptionBadge
                        }
                    }
                    .opacity(animateContent ? 1 : 0)
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateContent)
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeInOut(duration: 0.6).delay(0.3), value: animateContent)
                }
                
                // Follow Stats Row
                followStatsRow
                
                Spacer()
            }
        }
    }
    
    // ENHANCED: Profile Image (matching chat style)
    private var profileImageView: some View {
        Group {
            if let profileImageUrl = user.profileImageUrl,
               !profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [subscriptionTierColor(user.subscriptionTier).opacity(0.2), subscriptionTierColor(user.subscriptionTier).opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: subscriptionTierColor(user.subscriptionTier)))
                                .scaleEffect(0.8)
                        )
                }
            } else {
                // Fallback to initials circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [subscriptionTierColor(user.subscriptionTier).opacity(0.2), subscriptionTierColor(user.subscriptionTier).opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Text(String(user.fullName.prefix(1)))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(subscriptionTierColor(user.subscriptionTier))
                    )
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(subscriptionTierColor(user.subscriptionTier).opacity(0.3), lineWidth: 3)
        )
        .shadow(color: subscriptionTierColor(user.subscriptionTier).opacity(0.3), radius: 12, x: 0, y: 6)
        .scaleEffect(animateContent ? 1 : 0.8)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
    }
    
    private var subscriptionBadge: some View {
        Text(user.subscriptionTier.displayName.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(subscriptionTierColor(user.subscriptionTier))
                    .shadow(color: subscriptionTierColor(user.subscriptionTier).opacity(0.5), radius: 4, x: 0, y: 2)
            )
    }
    
    private var followStatsRow: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("\(user.followersCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Followers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(user.followingCount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Following")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text(memberSinceText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Member Since")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
    }
    
    // MARK: - Enhanced Stats Section
    private var enhancedStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trading Performance")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if user.winRate > 0.7 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Top Performer")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Win Rate Card
                enhancedStatCard(
                    title: "Win Rate",
                    value: "\(Int(user.winRate * 100))%",
                    subtitle: getWinRateDescription(user.winRate),
                    icon: "chart.line.uptrend.xyaxis",
                    color: user.winRate > 0.6 ? .green : .orange,
                    trend: user.winRate > 0.6 ? .up : .down
                )
                
                // Total P&L Card
                enhancedStatCard(
                    title: "Total P&L",
                    value: formatCurrency(user.totalProfitLoss),
                    subtitle: getProfitDescription(user.totalProfitLoss),
                    icon: "dollarsign.circle",
                    color: user.totalProfitLoss >= 0 ? .green : .red,
                    trend: user.totalProfitLoss >= 0 ? .up : .down
                )
                
                // Subscription Card
                enhancedStatCard(
                    title: "Subscription",
                    value: user.subscriptionTier.displayName,
                    subtitle: getSubscriptionDescription(user.subscriptionTier),
                    icon: "star.circle",
                    color: subscriptionTierColor(user.subscriptionTier),
                    trend: .neutral
                )
                
                // Communities Card
                enhancedStatCard(
                    title: "Communities",
                    value: "\(user.communityIds.count)",
                    subtitle: user.communityIds.count > 3 ? "Very Active" : "Active",
                    icon: "person.2.circle",
                    color: .purple,
                    trend: .neutral
                )
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.5), value: animateContent)
    }
    
    private func enhancedStatCard(title: String, value: String, subtitle: String, icon: String, color: Color, trend: TrendDirection) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if trend != .neutral {
                    Image(systemName: trend == .up ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(trend == .up ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(color)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Trading Performance Section
    private var tradingPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Stats")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                statRow("Starting Capital", formatCurrency(user.startingCapital))
                statRow("Current P&L", formatCurrency(user.totalProfitLoss))
                statRow("ROI", "\(calculateROI())%")
                statRow("Risk Rating", getRiskRating())
                statRow("Trading Style", getTradingStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.6), value: animateContent)
    }
    
    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Bio Section
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(bio)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.7), value: animateContent)
    }
    
    // MARK: - Communities Section
    private var communitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Communities (\(user.communityIds.count))")
                .font(.headline)
                .fontWeight(.bold)
            
            if user.communityIds.isEmpty {
                Text("No communities joined yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Community list would go here - for now showing count
                VStack(spacing: 8) {
                    ForEach(0..<min(3, user.communityIds.count), id: \.self) { index in
                        HStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("#")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Community \(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("Member since 2024")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    if user.communityIds.count > 3 {
                        Text("+ \(user.communityIds.count - 3) more communities")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.8), value: animateContent)
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                activityItem(
                    icon: "message.circle",
                    title: "Posted in Elite Traders",
                    subtitle: "2 hours ago",
                    color: .blue
                )
                
                activityItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Successful trade on AAPL",
                    subtitle: "1 day ago",
                    color: .green
                )
                
                activityItem(
                    icon: "person.badge.plus",
                    title: "Joined new community",
                    subtitle: "3 days ago",
                    color: .purple
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(0.9), value: animateContent)
    }
    
    private func activityItem(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Follow/Unfollow Button
                Button(action: toggleFollow) {
                    HStack(spacing: 8) {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(isFollowing ? "Unfollow" : "Follow")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(isFollowing ? .primary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isFollowing ? Color(.systemGray5) : subscriptionTierColor(user.subscriptionTier))
                            .shadow(color: isFollowing ? .clear : subscriptionTierColor(user.subscriptionTier).opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                
                // Message Button
                Button(action: { showingMessageComposer = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "message")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("Message")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(subscriptionTierColor(user.subscriptionTier))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .strokeBorder(subscriptionTierColor(user.subscriptionTier), lineWidth: 2)
                    )
                }
            }
            
            // Additional action buttons
            HStack(spacing: 12) {
                actionButton("Copy Trades", "doc.on.clipboard", .blue)
                actionButton("View Calls", "megaphone", .orange)
                actionButton("Share", "square.and.arrow.up", .green)
            }
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeInOut(duration: 0.6).delay(1.0), value: animateContent)
    }
    
    private func actionButton(_ title: String, _ icon: String, _ color: Color) -> some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }
    struct RoundedCorner: Shape {
        var radius: CGFloat = .infinity
        var corners: UIRectCorner = .allCorners

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            )
            return Path(path.cgPath)
        }
    }
    
    // MARK: - Helper Methods
    private var memberSinceText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: user.createdAt)
    }
    
    private func subscriptionTierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .purple
        }
    }
    
    private func getWinRateDescription(_ winRate: Double) -> String {
        switch winRate {
        case 0.8...: return "Exceptional"
        case 0.7..<0.8: return "Excellent"
        case 0.6..<0.7: return "Good"
        case 0.5..<0.6: return "Average"
        default: return "Needs Work"
        }
    }
    
    private func getProfitDescription(_ profit: Double) -> String {
        if profit >= 10000 {
            return "High Performer"
        } else if profit >= 1000 {
            return "Profitable"
        } else if profit >= 0 {
            return "Break Even"
        } else {
            return "At Loss"
        }
    }
    
    private func getSubscriptionDescription(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .basic: return "Standard Access"
        case .pro: return "Premium Features"
        case .elite: return "Full Access"
        }
    }
    
    private func calculateROI() -> Int {
        guard user.startingCapital > 0 else { return 0 }
        let roi = (user.totalProfitLoss / user.startingCapital) * 100
        return Int(roi)
    }
    
    private func getRiskRating() -> String {
        let roi = calculateROI()
        switch roi {
        case 50...: return "High Risk"
        case 20..<50: return "Medium Risk"
        case 0..<20: return "Low Risk"
        default: return "Conservative"
        }
    }
    
    private func getTradingStyle() -> String {
        // This could be determined by various factors
        return user.subscriptionTier == .elite ? "Day Trader" : "Swing Trader"
    }
    
    private func toggleFollow() {
        withAnimation(.spring()) {
            isFollowing.toggle()
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types
enum TrendDirection {
    case up, down, neutral
}
