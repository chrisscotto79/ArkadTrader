// File: Core/Communities/Views/Leaderboard/SimpleConsistencyLeaderboardView.swift
// Enhanced Leaderboard View - Modern Design with Working Follow Buttons & Profile Navigation

import SwiftUI

struct SimpleConsistencyLeaderboardView: View {
    let community: Community
    
    @StateObject private var viewModel = CommunityLeaderboardViewModel()
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    // Search functionality
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    @State private var showSearchResults = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    colors: [
                        Color.arkadGold.opacity(0.03),
                        Color(.systemGroupedBackground),
                        Color.arkadGold.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern Header
                    modernHeader
                    
                    // Search Bar
                    searchBar
                    
                    // Content
                    if showSearchResults {
                        searchContent
                    } else {
                        leaderboardMainContent
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadLeaderboard()
        }
    }
}

// MARK: - View Components
extension SimpleConsistencyLeaderboardView {
    
    private var modernHeader: some View {
        VStack(spacing: 20) {
            // Navigation and title
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.arkadGold, Color.arkadGoldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Leaderboard")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                    }
                    
                    Text(community.name)
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // Community avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.arkadGold, Color.arkadGoldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(getCommunityInitials(from: community.name))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Stats summary
            if !viewModel.leaderboardEntries.isEmpty {
                HStack(spacing: 20) {
                    statCard(
                        title: "Traders",
                        value: "\(viewModel.leaderboardEntries.count)",
                        icon: "person.3.fill",
                        color: .arkadGold
                    )
                    
                    statCard(
                        title: "Total Trades",
                        value: "\(viewModel.leaderboardEntries.reduce(0) { $0 + $1.totalTrades })",
                        icon: "chart.bar.fill",
                        color: .blue
                    )
                    
                    statCard(
                        title: "Avg Win Rate",
                        value: "\(String(format: "%.1f", viewModel.leaderboardEntries.map { $0.winRate }.reduce(0, +) / Double(viewModel.leaderboardEntries.count)))%",
                        icon: "target",
                        color: .green
                    )
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var searchBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    TextField("Search community members...", text: $searchText)
                        .font(.subheadline)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { _, newValue in
                            if newValue.isEmpty {
                                showSearchResults = false
                                searchResults = []
                            } else {
                                performSearch(query: newValue)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            showSearchResults = false
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                        )
                )
                
                if showSearchResults {
                    Button("Cancel") {
                        searchText = ""
                        showSearchResults = false
                        searchResults = []
                        hideKeyboard()
                    }
                    .font(.subheadline)
                    .foregroundColor(.arkadGold)
                }
            }
            .padding(.horizontal, 20)
            
            // Search mode toggle
            if !searchText.isEmpty {
                HStack {
                    Text(showSearchResults ? "Community Members" : "Community Leaderboard")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }
    
    private var searchContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if searchResults.isEmpty && !isSearching {
                    searchEmptyState
                } else {
                    ForEach(searchResults) { user in
                        SearchUserCard(user: user)
                            .environmentObject(authService)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            if !searchText.isEmpty {
                await performSearchAsync(query: searchText)
            }
        }
    }
    
    private var searchEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold)
            
            VStack(spacing: 8) {
                Text("No members found")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("Try searching for a different member in \(community.name)")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var leaderboardMainContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else if viewModel.leaderboardEntries.isEmpty {
                emptyStateView
            } else {
                leaderboardContent
            }
        }
    }
    
    private var leaderboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.leaderboardEntries) { entry in
                    EnhancedLeaderboardCard(entry: entry)
                        .environmentObject(authService)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            await refreshLeaderboard()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .foregroundColor(.arkadGold)
            
            Text("Loading rankings...")
                .font(.headline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Unable to Load Rankings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text(viewModel.errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Try Again") {
                loadLeaderboard()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.arkadGold)
                    .shadow(color: .arkadGold.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.arkadGold.opacity(0.2), Color.arkadGoldLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "trophy.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.arkadGold, Color.arkadGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(spacing: 16) {
                Text("No Rankings Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("Members need to complete trades to appear on the leaderboard!")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Helper Methods
extension SimpleConsistencyLeaderboardView {
    
    private func loadLeaderboard() {
        viewModel.loadLeaderboard(communityId: community.id)
    }
    
    private func refreshLeaderboard() async {
        await MainActor.run {
            viewModel.refresh(communityId: community.id)
        }
    }
    
    private func getCommunityInitials(from name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else { return }
        
        showSearchResults = true
        isSearching = true
        
        Task {
            await performSearchAsync(query: query)
        }
    }
    
    private func performSearchAsync(query: String) async {
        do {
            // ✅ FIRST: Get all community members
            let communityMembers = try await authService.getCommunityMembers(communityId: community.id)
            print("🏘️ Found \(communityMembers.count) community members")
            
            // ✅ DEBUG: Print all member details
            print("👥 Community members:")
            for (index, member) in communityMembers.enumerated() {
                print("   \(index + 1). ID: \(member.id)")
                print("      Username: '\(member.username)'")
                print("      Full Name: '\(member.fullName)'")
                print("      Bio: '\(member.bio ?? "nil")'")
                print("      Is Current User: \(member.id == authService.currentUser?.id)")
                print("   ───────────")
            }
            
            // ✅ SECOND: Filter members by search query
            let filteredMembers = communityMembers.filter { member in
                let searchQuery = query.lowercased()
                let usernameMatch = member.username.lowercased().contains(searchQuery)
                let fullNameMatch = member.fullName.lowercased().contains(searchQuery)
                let bioMatch = member.bio?.lowercased().contains(searchQuery) ?? false
                
                print("🔍 Checking member '\(member.username)':")
                print("   Username '\(member.username.lowercased())' contains '\(searchQuery)': \(usernameMatch)")
                print("   Full Name '\(member.fullName.lowercased())' contains '\(searchQuery)': \(fullNameMatch)")
                print("   Bio '\(member.bio?.lowercased() ?? "nil")' contains '\(searchQuery)': \(bioMatch)")
                print("   Overall match: \(usernameMatch || fullNameMatch || bioMatch)")
                
                return usernameMatch || fullNameMatch || bioMatch
            }
            
            // ✅ THIRD: Remove current user from results
            let finalResults = filteredMembers.filter { $0.id != authService.currentUser?.id }
            
            print("🔍 Search for '\(query)' found \(finalResults.count) community members")
            print("📊 Search Summary:")
            print("   Total community members: \(communityMembers.count)")
            print("   Members matching '\(query)': \(filteredMembers.count)")
            print("   Final results (excluding current user): \(finalResults.count)")
            
            await MainActor.run {
                self.searchResults = finalResults
                self.isSearching = false
            }
        } catch {
            print("❌ Community search error: \(error)")
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Search User Card
struct SearchUserCard: View {
    let user: User
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showUserProfile = false
    
    var body: some View {
        Button(action: {
            showUserProfile = true
        }) {
            HStack(spacing: 16) {
                // User Avatar
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(user.username)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.arkadGold)
                        .overlay(
                            Text(userInitials)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.arkadGold.opacity(0.3), lineWidth: 2)
                )
                
                // User Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.fullName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Stats & Follow
                VStack(alignment: .trailing, spacing: 8) {
                    // User Stats
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text("\(user.followersCount ?? 0)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                            Text("Followers")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                        
                        VStack(spacing: 2) {
                            Text(formatCurrency(user.totalProfitLoss))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(user.totalProfitLoss >= 0 ? .green : .red)
                            Text("P&L")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    // Follow Button (smaller version)
                    Button(action: {
                        // This prevents the card tap from triggering
                    }) {
                        SimpleFollowButton(
                            targetUserId: user.id,
                            targetUsername: user.username
                        )
                        .scaleEffect(0.8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showUserProfile) {
            OtherUserProfileView(user: user)
                .environmentObject(authService)
        }
    }
    
    private var userInitials: String {
        let names = user.fullName.split(separator: " ")
        if names.count > 1 {
            let firstInitial = names.first?.first ?? Character("U")
            let lastInitial = names.last?.first ?? Character("U")
            return String(firstInitial) + String(lastInitial)
        } else {
            let username = user.fullName
            let firstChar = username.first ?? Character("U")
            let secondChar = username.count > 1 ? username[username.index(username.startIndex, offsetBy: 1)] : Character("U")
            return String(firstChar) + String(secondChar)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 0 {
            return "+$\(String(format: "%.0f", amount))"
        } else {
            return "-$\(String(format: "%.0f", abs(amount)))"
        }
    }
}

// MARK: - Enhanced Leaderboard Card
struct EnhancedLeaderboardCard: View {
    let entry: CommunityLeaderboardEntry
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showOtherUserProfile = false
    @State private var profileUser: User?
    @State private var isLoadingUser = false
    
    private var isCurrentUser: Bool {
        authService.currentUser?.id == entry.userId
    }
    
    var body: some View {
        VStack(spacing: 0) {
            mainCardContent
            
            if !isCurrentUser {
                followButtonSection
            }
        }
        .background(cardBackground)
        .sheet(isPresented: $showOtherUserProfile) {
            if let profileUser = profileUser {
                OtherUserProfileView(user: profileUser)
                    .environmentObject(authService)
            }
        }
    }
    
    private var mainCardContent: some View {
        VStack(spacing: 20) {
            cardHeader
            statsGrid
        }
        .padding(24)
    }
    
    private var cardHeader: some View {
        HStack(spacing: 16) {
            rankBadge
            userInfoSection
            performanceIndicator
        }
    }
    
    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankGradient)
                .frame(width: 56, height: 56)
                .shadow(color: rankColor.opacity(0.4), radius: 8, x: 0, y: 4)
            
            if entry.rank <= 3 {
                Image(systemName: rankIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("#\(entry.rank)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                if !isCurrentUser {
                    handleProfileTap()
                }
            }) {
                HStack(spacing: 8) {
                    userAvatar
                    userDetails
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isCurrentUser)
        }
    }
    
    private var userAvatar: some View {
        AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(entry.username)")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color.arkadGold)
                .overlay(
                    Text(userInitials)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.arkadGold.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var userDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(entry.username)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                if isCurrentUser {
                    youBadge
                }
            }
            
            winRateIndicator
        }
    }
    
    private var youBadge: some View {
        Text("(You)")
            .font(.caption)
            .foregroundColor(.arkadGold)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.arkadGold.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                    )
            )
    }
    
    private var winRateIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(entry.totalProfitLoss >= 0 ? .green : .red)
                .frame(width: 6, height: 6)
            
            Text("\(String(format: "%.1f", entry.winRate))% win rate")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }
    
    private var performanceIndicator: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(formatProfitLoss(entry.totalProfitLoss))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(entry.totalProfitLoss >= 0 ? .green : .red)
            
            Text("Total P&L")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
    
    private var statsGrid: some View {
        HStack(spacing: 0) {
            statItem(
                title: "Total Trades",
                value: "\(entry.totalTrades)",
                icon: "chart.bar.fill",
                color: .blue
            )
            
            Divider()
                .frame(height: 50)
                .padding(.horizontal, 8)
            
            statItem(
                title: "Win Rate",
                value: "\(String(format: "%.1f", entry.winRate))%",
                icon: "target",
                color: .green
            )
            
            Divider()
                .frame(height: 50)
                .padding(.horizontal, 8)
            
            statItem(
                title: "Trader Level",
                value: getTraderLevel(),
                icon: "star.fill",
                color: .arkadGold
            )
        }
        .padding(.horizontal, 8)
    }
    
    private var followButtonSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 24)
            
            SimpleFollowButton(
                targetUserId: entry.userId,
                targetUsername: entry.username
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
    
    private var strokeColor: Color {
        isCurrentUser ? Color.arkadGold.opacity(0.6) : Color.clear.opacity(0.1)
    }
    
    private var strokeWidth: CGFloat {
        isCurrentUser ? 2 : 1
    }
    
    private var shadowColor: Color {
        isCurrentUser ? Color.arkadGold.opacity(0.2) : Color.black.opacity(0.08)
    }
    
    private var shadowRadius: CGFloat {
        isCurrentUser ? 12 : 8
    }
    
    private var shadowY: CGFloat {
        isCurrentUser ? 6 : 4
    }
    
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var rankGradient: LinearGradient {
        switch entry.rank {
        case 1:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            return LinearGradient(colors: [.gray, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var rankIcon: String {
        switch entry.rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal"
        default: return ""
        }
    }
    
    private var userInitials: String {
        let names = entry.username.split(separator: " ")
        if names.count > 1 {
            let firstInitial = names.first?.first ?? Character("U")
            let lastInitial = names.last?.first ?? Character("U")
            return String(firstInitial) + String(lastInitial)
        } else {
            let username = entry.username
            let firstChar = username.first ?? Character("U")
            let secondChar = username.count > 1 ? username[username.index(username.startIndex, offsetBy: 1)] : Character("U")
            return String(firstChar) + String(secondChar)
        }
    }
    
    private func getTraderLevel() -> String {
        if entry.totalTrades < 5 {
            return "Beginner"
        } else if entry.totalTrades < 20 {
            return "Growing"
        } else if entry.totalTrades < 50 {
            return "Active"
        } else if entry.winRate > 70 {
            return "Expert"
        } else {
            return "Veteran"
        }
    }
    
    private func formatProfitLoss(_ amount: Double) -> String {
        if amount >= 0 {
            return "+$\(String(format: "%.0f", amount))"
        } else {
            return "-$\(String(format: "%.0f", abs(amount)))"
        }
    }
    
    private func handleProfileTap() {
        Task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        guard profileUser == nil else {
            await MainActor.run {
                showOtherUserProfile = true
            }
            return
        }
        
        await MainActor.run {
            isLoadingUser = true
        }
        
        do {
            if let user = try await authService.getUserById(userId: entry.userId) {
                await MainActor.run {
                    profileUser = user
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            } else {
                await MainActor.run {
                    profileUser = createMinimalUser()
                    isLoadingUser = false
                    showOtherUserProfile = true
                }
            }
        } catch {
            print("❌ Error loading user profile: \(error)")
            
            await MainActor.run {
                profileUser = createMinimalUser()
                isLoadingUser = false
                showOtherUserProfile = true
            }
        }
    }
    
    private func createMinimalUser() -> User {
        var user = User(
            id: entry.userId,
            email: "\(entry.username)@example.com",
            username: entry.username,
            fullName: entry.username.capitalized
        )
        
        user.bio = "Trader on ArkadTrader"
        user.followersCount = 0
        user.followingCount = 0
        user.totalProfitLoss = entry.totalProfitLoss
        user.winRate = entry.winRate
        
        return user
    }
}

#Preview {
    SimpleConsistencyLeaderboardView(
        community: Community(
            name: "Test Community",
            description: "Test",
            type: .general,
            createdBy: "test"
        )
    )
    .environmentObject(FirebaseAuthService.shared)
}
