// File: Core/Search/Views/SearchResultView.swift
// Enhanced Search Result View with polished design matching the original

import SwiftUI

struct SearchResultView: View {
    let result: SearchResult
    @State private var showDetail = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showDetail = true
            }
        }) {
            HStack(spacing: 16) {
                // Enhanced Icon/Avatar
                resultIcon
                
                // Content Section
                VStack(alignment: .leading, spacing: 6) {
                    // Primary Text
                    Text(primaryText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.arkadBlack)
                        .lineLimit(1)
                    
                    // Secondary Text
                    Text(secondaryText)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    // Additional Info
                    if let additionalInfo = additionalInfo {
                        Text(additionalInfo)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(additionalInfoColor)
                    }
                }
                
                Spacer()
                
                // Action Section
                VStack(spacing: 8) {
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    // Action Button
                    actionButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(
                        color: .gray.opacity(isPressed ? 0.2 : 0.08),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
        .sheet(isPresented: $showDetail) {
            NavigationView {
                destinationView
                    .navigationBarTitle(navigationTitle, displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showDetail = false
                                }
                            }
                            .foregroundColor(.arkadGold)
                        }
                    }
            }
        }
    }
    
    // MARK: - Result Icon/Avatar
    
    @ViewBuilder
    private var resultIcon: some View {
        switch result.type {
        case .user:
            userAvatar
        case .post:
            postIcon
        case .trade:
            tradeIcon
        case .group:
            groupIcon
        }
    }
    
    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            if let user = result.user {
                Text(user.fullName.prefix(1).uppercased())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var postIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 24))
                .foregroundColor(.purple)
            
            // Small comment indicator
            if let post = result.post, post.commentsCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                            )
                            .offset(x: 8, y: 8)
                    }
                }
            }
        }
    }
    
    private var tradeIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24))
                .foregroundColor(.green)
        }
    }
    
    private var groupIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Image(systemName: "person.3.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
        }
    }
    
    // MARK: - Action Button
    
    @ViewBuilder
    private var actionButton: some View {
        switch result.type {
        case .user:
            Text("View")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        case .post:
            Text("Read")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
        case .trade:
            Text("Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
        case .group:
            Text("Join")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Content Properties
    
    private var primaryText: String {
        switch result.type {
        case .user:
            return result.user?.fullName ?? "Unknown User"
        case .post:
            let content = result.post?.content ?? "Post"
            return String(content.prefix(50))
        case .trade:
            return result.trade?.ticker ?? "Trade"
        case .group:
            return result.community?.name ?? "Group"
        }
    }
    
    private var secondaryText: String {
        switch result.type {
        case .user:
            return "@\(result.user?.username ?? "username")"
        case .post:
            return "by @\(result.post?.authorUsername ?? "unknown")"
        case .trade:
            let trade = result.trade
            return trade?.isOpen ?? true ? "Open Position" : "Closed Position"
        case .group:
            return "\(result.community?.memberCount ?? 0) members"
        }
    }
    
    private var additionalInfo: String? {
        switch result.type {
        case .user:
            if let winRate = result.user?.winRate {
                return "Win Rate: \(String(format: "%.1f%%", winRate))"
            }
            return nil
        case .post:
            if let likesCount = result.post?.likesCount, likesCount > 0 {
                return "\(likesCount) likes"
            }
            return "0 likes"
        case .trade:
            if let trade = result.trade {
                if trade.isOpen {
                    return "Active"
                } else {
                    return String(format: "%.2f%% P&L", trade.profitLossPercentage)
                }
            }
            return nil
        case .group:
            return result.community?.isPrivate ?? false ? "Private Group" : "Public Group"
        }
    }
    
    private var additionalInfoColor: Color {
        switch result.type {
        case .user:
            return .blue
        case .post:
            return .gray
        case .trade:
            if let trade = result.trade, !trade.isOpen {
                return trade.profitLossPercentage >= 0 ? .green : .red
            }
            return .green
        case .group:
            return .gray
        }
    }
    
    private var navigationTitle: String {
        switch result.type {
        case .user: return "Profile"
        case .post: return "Post"
        case .trade: return "Trade"
        case .group: return "Community"
        }
    }
    
    // MARK: - Destination View
    
    @ViewBuilder
    private var destinationView: some View {
        switch result.type {
        case .user:
            if let user = result.user {
                SimpleUserProfileView(user: user)
            } else {
                errorView(message: "User not found")
            }
        case .post:
            if let post = result.post {
                SimplePostDetailView(post: post)
            } else {
                errorView(message: "Post not found")
            }
        case .trade:
            if let trade = result.trade {
                SimpleTradeDetailView(trade: trade)
            } else {
                errorView(message: "Trade not found")
            }
        case .group:
            if let community = result.community {
                SimpleCommunityDetailView(community: community)
            } else {
                errorView(message: "Community not found")
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Simple Detail Views (Unchanged from previous implementation)

struct SimpleUserProfileView: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isFollowing = false
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Text(user.fullName.prefix(1).uppercased())
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadBlack)
                        
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                }
                
                // Stats
                HStack(spacing: 32) {
                    statItem(title: "Followers", value: "\(user.followersCount)")
                    statItem(title: "Following", value: "\(user.followingCount)")
                    statItem(title: "Win Rate", value: String(format: "%.1f%%", user.winRate))
                }
                
                // Follow Button
                if user.id != authService.currentUser?.id {
                    Button(action: toggleFollow) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                                    .font(.subheadline)
                            }
                            Text(isFollowing ? "Following" : "Follow")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(isFollowing ? Color.gray : Color.arkadGold)
                        .cornerRadius(25)
                        .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isLoading)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.white)
    }
    
    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.arkadBlack)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private func toggleFollow() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isFollowing.toggle()
                isLoading = false
            }
        }
    }
}

struct SimplePostDetailView: View {
    let post: Post
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Post Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(post.authorUsername.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.purple)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(post.authorUsername)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // Post Content
                Text(post.content)
                    .font(.body)
                    .lineSpacing(4)
                
                // Interaction Bar
                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("\(post.likesCount)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("\(post.commentsCount)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
        .background(Color.white)
    }
}

struct SimpleTradeDetailView: View {
    let trade: Trade
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Trade Header
                VStack(spacing: 16) {
                    HStack {
                        Text(trade.ticker)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadBlack)
                        
                        Spacer()
                        
                        Text(trade.isOpen ? "OPEN" : "CLOSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(trade.isOpen ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    if !trade.isOpen {
                        Text(String(format: "%.2f%% P&L", trade.profitLossPercentage))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(trade.profitLossPercentage >= 0 ? .green : .red)
                    }
                }
                
                // Trade Details
                VStack(spacing: 16) {
                    detailRow(label: "Type", value: trade.tradeType.displayName)
                    detailRow(label: "Entry Price", value: "$\(String(format: "%.2f", trade.entryPrice))")
                    detailRow(label: "Quantity", value: "\(trade.quantity)")
                    detailRow(label: "Entry Date", value: trade.formattedEntryDate)
                }
                
                if let notes = trade.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(notes)
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.white)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.arkadBlack)
        }
        .padding(.vertical, 4)
    }
}

struct SimpleCommunityDetailView: View {
    let community: Community
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Community Header
                VStack(alignment: .leading, spacing: 16) {
                    Text(community.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.arkadBlack)
                    
                    Text(community.description)
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text("\(community.memberCount) members")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Text(community.isPrivate ? "Private" : "Public")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(community.isPrivate ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                            .foregroundColor(community.isPrivate ? .red : .green)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.white)
    }
}
