// File: Core/Search/Views/SearchResultView.swift
// ENHANCED - SearchResultView with complete navigation implementation

import SwiftUI

struct SearchResultView: View {
    let result: SearchResult
    @EnvironmentObject private var authService: FirebaseAuthService
    
    // Navigation states
    @State private var showUserProfile = false
    @State private var showPostDetail = false
    @State private var showTradeDetail = false
    @State private var showCommunityDetail = false
    @State private var isLoadingUser = false
    @State private var profileUser: User?
    
    var body: some View {
        Button(action: {
            handleResultTap()
        }) {
            HStack(spacing: 12) {
                // Result Icon/Avatar
                resultIcon
                
                // Main Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(secondaryText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let additionalInfo = additionalInfo {
                        Text(additionalInfo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(additionalInfoColor)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Result Type Badge
                resultTypeBadge
                
                // Loading indicator for user profiles
                if isLoadingUser && result.type == .user {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.arkadGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        // Navigation sheets
        .sheet(isPresented: $showUserProfile) {
            userProfileSheet
        }
        .sheet(isPresented: $showPostDetail) {
            postDetailSheet
        }
        .sheet(isPresented: $showTradeDetail) {
            tradeDetailSheet
        }
        .sheet(isPresented: $showCommunityDetail) {
            communityDetailSheet
        }
    }
    
    // MARK: - Result Icon
    @ViewBuilder
    private var resultIcon: some View {
        switch result.type {
        case .user:
            AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(result.user?.username ?? "user")")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .overlay(
                        Text(userInitials)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.arkadGold)
                    )
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
        case .post:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 18))
                )
            
        case .trade:
            RoundedRectangle(cornerRadius: 8)
                .fill(tradeColor.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(tradeColor)
                        .font(.system(size: 18))
                )
            
        case .group:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                )
        }
    }
    
    // MARK: - Result Type Badge
    @ViewBuilder
    private var resultTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.type.icon)
                .font(.system(size: 10))
                .foregroundColor(badgeColor)
            
            Text(result.type.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Text Content
    private var primaryText: String {
        switch result.type {
        case .user:
            return result.user?.fullName ?? result.user?.username ?? "Unknown User"
        case .post:
            return String(result.post?.content.prefix(80) ?? "Post content")
        case .trade:
            return "\(result.trade?.ticker ?? "UNKNOWN") Trade"
        case .group:
            return result.community?.name ?? "Community"
        }
    }
    
    private var secondaryText: String {
        switch result.type {
        case .user:
            return "@\(result.user?.username ?? "username")"
        case .post:
            return "by @\(result.post?.authorUsername ?? "unknown")"
        case .trade:
            if let trade = result.trade {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return trade.isOpen ? "Active" : "Closed \(formatter.string(from: trade.exitDate ?? trade.entryDate))"
            }
            return "Trade"
        case .group:
            return "\(result.community?.memberCount ?? 0) members"
        }
    }
    
    private var additionalInfo: String? {
        switch result.type {
        case .user:
            if let user = result.user {
                if user.winRate > 0 {
                    return "Win Rate: \(String(format: "%.1f%%", user.winRate))"
                }
                return "Trader"
            }
            return nil
            
        case .post:
            if let post = result.post {
                let likes = post.likesCount
                let comments = post.commentsCount
                if likes > 0 || comments > 0 {
                    return "\(likes) likes • \(comments) comments"
                }
            }
            return "0 interactions"
            
        case .trade:
            if let trade = result.trade {
                if trade.isOpen {
                    return "Active • Entry: $\(String(format: "%.2f", trade.entryPrice))"
                } else {
                    return String(format: "%.2f%% P&L", trade.profitLossPercentage)
                }
            }
            return nil
            
        case .group:
            return result.community?.isPrivate ?? false ? "Private" : "Public"
        }
    }
    
    // MARK: - Helper Computed Properties
    private var userInitials: String {
        guard let user = result.user else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
    
    // MARK: - Colors
    private var additionalInfoColor: Color {
        switch result.type {
        case .user:
            return .arkadGold
        case .post:
            return .secondary
        case .trade:
            if let trade = result.trade, !trade.isOpen {
                return trade.profitLossPercentage >= 0 ? .green : .red
            }
            return .arkadGold
        case .group:
            return result.community?.isPrivate ?? false ? .red : .green
        }
    }
    
    private var tradeColor: Color {
        if let trade = result.trade, !trade.isOpen {
            return trade.profitLossPercentage >= 0 ? .green : .red
        }
        return .arkadGold
    }
    
    private var badgeColor: Color {
        switch result.type {
        case .user: return .blue
        case .post: return .purple
        case .trade: return tradeColor
        case .group: return .orange
        }
    }
    
    // MARK: - Navigation Actions
    private func handleResultTap() {
        switch result.type {
        case .user:
            handleUserTap()
            
        case .post:
            showPostDetail = true
            
        case .trade:
            showTradeDetail = true
            
        case .group:
            showCommunityDetail = true
        }
    }
    
    private func handleUserTap() {
        guard let user = result.user else { return }
        
        // Check if this is the current user
        if let currentUser = authService.currentUser, currentUser.id == user.id {
            print("👤 User tapped their own profile from search - not opening modal")
            return
        }
        
        // Load other user's profile (same pattern as UserPostCard)
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        guard let user = result.user else { return }
        
        // Check if we already have the profile loaded
        guard profileUser == nil else {
            await MainActor.run {
                showUserProfile = true
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
        }
        
        do {
            print("🔍 Fetching user by ID: \(user.id)")
            
            if let fullUser = try await authService.getUserById(userId: user.id) {
                print("✅ User found: \(fullUser.username)")
                await MainActor.run {
                    profileUser = fullUser
                    isLoadingUser = false
                    showUserProfile = true
                }
            } else {
                print("⚠️ User not found, creating minimal user")
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    showUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                showUserProfile = true
            }
        }
    }
    
    private func createMinimalUser() -> User {
        guard let user = result.user else {
            return User(id: "unknown", email: "unknown@example.com", username: "unknown", fullName: "Unknown User")
        }
        
        print("🔨 Creating minimal user for: \(user.username)")
        
        var minimalUser = User(
            id: user.id,
            email: "\(user.username)@example.com",
            username: user.username,
            fullName: user.fullName
        )
        
        minimalUser.bio = "Trader on ArkadTrader"
        minimalUser.followersCount = user.followersCount ?? 0
        minimalUser.followingCount = user.followingCount ?? 0
        minimalUser.totalProfitLoss = user.totalProfitLoss
        minimalUser.winRate = user.winRate
        
        return minimalUser
    }
    
    // MARK: - Sheet Views
    @ViewBuilder
    private var userProfileSheet: some View {
        if let profileUser = profileUser {
            OtherUserProfileView(user: profileUser)
                .environmentObject(authService)
        } else {
            // Same fallback pattern as UserPostCard
            VStack(spacing: 20) {
                Text("Unable to load profile")
                    .font(.headline)
                
                Text("User: @\(result.user?.username ?? "unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Dismiss") {
                    showUserProfile = false
                }
                .foregroundColor(.blue)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var postDetailSheet: some View {
        NavigationView {
            VStack {
                if let post = result.post {
                    // Create a mock HomeViewModel for the post card
                    UserPostCard(post: post, homeViewModel: HomeViewModel())
                        .environmentObject(authService)
                        .padding()
                    
                    Spacer()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Post Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Unable to load post content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Done") {
                    showPostDetail = false
                }
                .foregroundColor(.arkadGold)
            )
        }
    }
    
    @ViewBuilder
    private var tradeDetailSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let trade = result.trade {
                    // Trade header
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(tradeColor)
                        
                        Text(trade.ticker)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(trade.isOpen ? "Active Trade" : "Closed Trade")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(tradeColor.opacity(0.1))
                            .foregroundColor(tradeColor)
                            .cornerRadius(20)
                    }
                    
                    // Trade details
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Entry Price")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(String(format: "%.2f", trade.entryPrice))")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            if !trade.isOpen {
                                VStack(alignment: .trailing) {
                                    Text("Exit Price")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(String(format: "%.2f", trade.exitPrice ?? 0))")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        
                        if !trade.isOpen {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("P&L")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f%%", trade.profitLossPercentage))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(trade.profitLossPercentage >= 0 ? .green : .red)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("Entry Date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(DateFormatter().string(from: trade.entryDate))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Trade Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Unable to load trade information")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("Trade Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Done") {
                    showTradeDetail = false
                }
                .foregroundColor(.arkadGold)
            )
        }
    }
    
    @ViewBuilder
    private var communityDetailSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let community = result.community {
                    // Community header
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(community.name.prefix(1)).uppercased())
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            )
                        
                        Text(community.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .font(.caption)
                                Text("\(community.memberCount) members")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: community.isPrivate ? "lock.fill" : "globe")
                                    .font(.caption)
                                Text(community.isPrivate ? "Private" : "Public")
                                    .font(.subheadline)
                            }
                            .foregroundColor(community.isPrivate ? .red : .green)
                        }
                    }
                    
                    // Community description
                    if !community.description.isEmpty {
                        Text(community.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // TODO: Implement join community
                            print("Join community: \(community.name)")
                        }) {
                            Text(community.isPrivate ? "Request to Join" : "Join Community")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.arkadGold)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // TODO: Implement view community details
                            print("View community details: \(community.name)")
                        }) {
                            Text("View Details")
                                .font(.headline)
                                .foregroundColor(.arkadGold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.arkadGold.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Community Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Unable to load community information")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Done") {
                    showCommunityDetail = false
                }
                .foregroundColor(.arkadGold)
            )
        }
    }
}

#Preview {
    let sampleUser = User(id: "1", email: "test@example.com", username: "testuser", fullName: "Test User")
    let sampleResult = SearchResult(user: sampleUser)
    
    SearchResultView(result: sampleResult)
        .environmentObject(FirebaseAuthService.shared)
        .padding()
}
