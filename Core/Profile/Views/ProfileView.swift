// File: Core/Profile/Views/ProfileView.swift
// Complete Profile View with user posts, trades, portfolio, and groups - FIXED

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var postsViewModel = UserPostsViewModel()
    @StateObject private var groupsViewModel = UserGroupsViewModel()
    
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedTab: ProfileTab = .posts
    @State private var showPortfolioDetails = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header with full-screen banner
                ProfileHeaderSection(
                    user: authService.currentUser,
                    portfolioSummary: portfolioViewModel.getPortfolioSummaryForProfile(),
                    showEditProfile: $showEditProfile,
                    showSettings: $showSettings
                )
                
                // Portfolio Performance Banner
                PortfolioPerformanceBanner(
                    portfolioSummary: portfolioViewModel.getPortfolioSummaryForProfile(),
                    showPortfolioDetails: $showPortfolioDetails
                )
                
                // Tab Selection
                ProfileTabSelector(selectedTab: $selectedTab)
                
                // Tab Content
                ProfileTabContent(
                    selectedTab: selectedTab,
                    portfolioViewModel: portfolioViewModel,
                    postsViewModel: postsViewModel,
                    groupsViewModel: groupsViewModel
                )
            }
        }
        .ignoresSafeArea(edges: .top) // Allow content to extend to very top
        .refreshable {
            await refreshProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPortfolioDetails) {
            PortfolioDetailsSheet()
                .environmentObject(portfolioViewModel)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
            postsViewModel.loadUserPosts(userId: authService.currentUser?.id ?? "")
            groupsViewModel.loadUserGroups(userId: authService.currentUser?.id ?? "")
        }
    }
    
    @MainActor
    private func refreshProfile() async {
        portfolioViewModel.refreshPortfolio()
        await postsViewModel.refreshPosts()
        await groupsViewModel.refreshGroups()
    }
}

// MARK: - Profile Header Section
struct ProfileHeaderSection: View {
    let user: User?
    let portfolioSummary: PortfolioSummary
    @Binding var showEditProfile: Bool
    @Binding var showSettings: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Clean background with subtle tech patterns only
                ZStack {
                    // Very subtle base background
                    Color.white
                    
                    // Geometric pattern overlay (keeping the tech design)
                    ZStack {
                        // Diagonal lines pattern
                        Path { path in
                            let spacing: CGFloat = 60
                            
                            for i in stride(from: -geometry.size.width, to: geometry.size.width * 2, by: spacing) {
                                path.move(to: CGPoint(x: i, y: 0))
                                path.addLine(to: CGPoint(x: i + geometry.size.height, y: geometry.size.height))
                            }
                        }
                        .stroke(Color.arkadGold.opacity(0.08), lineWidth: 0.6)
                        
                        // Tech grid overlay
                        Path { path in
                            let gridSize: CGFloat = 40
                            
                            // Horizontal lines
                            for y in stride(from: 0, through: geometry.size.height, by: gridSize) {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                            
                            // Vertical lines
                            for x in stride(from: 0, through: geometry.size.width, by: gridSize) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                            }
                        }
                        .stroke(Color.arkadGold.opacity(0.04), lineWidth: 0.3)
                        
                        // Enhanced floating tech elements
                        enhancedTechElements(geometry: geometry)
                    }
                    
                    // Very subtle radial highlight around avatar only
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.arkadGold.opacity(0.06),
                            Color.arkadGold.opacity(0.03),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 80,
                        endRadius: 150
                    )
                    .offset(y: 100)
                }
                
                // Profile content with proper spacing for safe area
                VStack(spacing: 20) {
                    // Top spacing for safe area
                    Spacer()
                        .frame(height: 50)
                    
                    // Top navigation with arkadgold accents
                    HStack {
                        VStack(alignment: .leading) {
                            Text(user?.fullName ?? "Unknown User")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                            
                            Text("@\(user?.username ?? "username")")
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.arkadGold)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .shadow(color: Color.arkadGold.opacity(0.3), radius: 6, x: 0, y: 3)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Profile Avatar with enhanced styling
                    ZStack {
                        // Outer tech ring effect (reduced opacity)
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.arkadGold.opacity(0.15),
                                        Color.arkadGold.opacity(0.08),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 90
                                )
                            )
                            .frame(width: 150, height: 150)
                        
                        // Tech border rings
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .stroke(
                                    Color.arkadGold.opacity(0.3 - Double(index) * 0.05),
                                    lineWidth: 2.0 - CGFloat(index) * 0.3
                                )
                                .frame(width: 115 + CGFloat(index) * 10, height: 115 + CGFloat(index) * 10)
                        }
                        
                        // Main avatar circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.arkadGold,
                                        Color.arkadGoldLight
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 5)
                            )
                            .overlay(
                                Text(getInitials(user: user))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: Color.arkadGold.opacity(0.6), radius: 20, x: 0, y: 10)
                    }
                    
                    // User stats with enhanced styling
                    HStack {
                        Spacer()
                        
                        statColumn(
                            number: "\(user?.followersCount ?? 0)",
                            label: "Followers"
                        )
                        
                        Spacer()
                        
                        statColumn(
                            number: "\(user?.followingCount ?? 0)",
                            label: "Following"
                        )
                        
                        Spacer()
                        
                        statColumn(
                            number: "\(portfolioSummary.totalTrades)",
                            label: "Trades"
                        )
                        
                        Spacer()
                        
                        statColumn(
                            number: String(format: "%.1f%%", portfolioSummary.winRate),
                            label: "Win Rate"
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Clean bio section (no background/border)
                    if let bio = user?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 35)
                    }
                    
                    // Action Buttons with enhanced styling
                    HStack(spacing: 15) {
                        Button(action: { showEditProfile = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil")
                                    .font(.subheadline)
                                Text("Edit Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.arkadGold, Color.arkadGoldLight]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.arkadGold.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        
                        Button(action: {
                            shareProfile()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline)
                                Text("Share Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.arkadGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white)
                                    .shadow(color: Color.arkadGold.opacity(0.3), radius: 6, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.arkadGold, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(height: 500) // Fixed height for the header section
        .clipped()
        .ignoresSafeArea(edges: .top) // Extend to the very top
    }
    
    // Enhanced tech elements for full-screen design
    private func enhancedTechElements(geometry: GeometryProxy) -> some View {
        ZStack {
            // Top tech elements
            Circle()
                .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1.5)
                .frame(width: 25, height: 25)
                .position(x: geometry.size.width * 0.15, y: geometry.size.height * 0.15)
            
            Circle()
                .stroke(Color.arkadGold.opacity(0.15), lineWidth: 1)
                .frame(width: 18, height: 18)
                .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.12)
            
            Circle()
                .stroke(Color.arkadGold.opacity(0.18), lineWidth: 1.2)
                .frame(width: 20, height: 20)
                .position(x: geometry.size.width * 0.75, y: geometry.size.height * 0.25)
            
            // Middle area elements
            Circle()
                .stroke(Color.arkadGold.opacity(0.12), lineWidth: 1)
                .frame(width: 15, height: 15)
                .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.45)
            
            Circle()
                .stroke(Color.arkadGold.opacity(0.16), lineWidth: 1.3)
                .frame(width: 22, height: 22)
                .position(x: geometry.size.width * 0.9, y: geometry.size.height * 0.4)
            
            // Tech connection lines
            Rectangle()
                .fill(Color.arkadGold.opacity(0.1))
                .frame(width: geometry.size.width * 0.4, height: 1.5)
                .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)
            
            Rectangle()
                .fill(Color.arkadGold.opacity(0.08))
                .frame(width: geometry.size.width * 0.3, height: 1.2)
                .position(x: geometry.size.width * 0.7, y: geometry.size.height * 0.35)
            
            Rectangle()
                .fill(Color.arkadGold.opacity(0.12))
                .frame(width: geometry.size.width * 0.25, height: 1.8)
                .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.5)
        }
    }
    
    // Stat column with arkadgold accents
    private func statColumn(number: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.arkadGold)
                .fontWeight(.medium)
        }
    }
    
    private func shareProfile() {
        guard let user = user else { return }
        
        let shareText = """
        Check out @\(user.username) on ArkadTrader!
        
        📈 Win Rate: \(String(format: "%.1f", portfolioSummary.winRate))%
        💰 Total P&L: \(portfolioSummary.totalProfitLoss.asCurrencyWithSign)
        🎯 Total Trades: \(portfolioSummary.totalTrades)
        
        Join the trading community: ArkadTrader
        """
        
        UIPasteboard.general.string = shareText
    }
    
    private func getInitials(user: User?) -> String {
        guard let user = user else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
}

// MARK: - Portfolio Performance Banner
struct PortfolioPerformanceBanner: View {
    let portfolioSummary: PortfolioSummary
    @Binding var showPortfolioDetails: Bool
    
    var body: some View {
        Button(action: { showPortfolioDetails = true }) {
            VStack(spacing: 16) {
                // Header with title and view details
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title3)
                                .foregroundColor(.arkadGold)
                            
                            Text("Portfolio Performance")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                        }
                        
                        Text("Tap to view detailed analytics")
                            .font(.caption)
                            .foregroundColor(.arkadGold.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.arkadGold)
                        .padding(8)
                        .background(Color.arkadGold.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Performance metrics grid
                VStack(spacing: 12) {
                    // Top row - Total P&L and Win Rate
                    HStack(spacing: 16) {
                        metricCard(
                            icon: "dollarsign.circle.fill",
                            title: "Total P&L",
                            value: portfolioSummary.totalProfitLoss.asCurrencyWithSign,
                            color: portfolioSummary.totalProfitLoss >= 0 ? .marketGreen : .marketRed,
                            isMainMetric: true
                        )
                        
                        metricCard(
                            icon: "target",
                            title: "Win Rate",
                            value: String(format: "%.1f%%", portfolioSummary.winRate),
                            color: portfolioSummary.winRate >= 50 ? .marketGreen : .marketRed,
                            isMainMetric: true
                        )
                    }
                    
                    // Bottom row - Today's P&L and Total Trades
                    HStack(spacing: 16) {
                        metricCard(
                            icon: "calendar",
                            title: "Today",
                            value: portfolioSummary.dayProfitLoss.asCurrencyWithSign,
                            color: portfolioSummary.dayProfitLoss >= 0 ? .marketGreen : .marketRed,
                            isMainMetric: false
                        )
                        
                        metricCard(
                            icon: "number.circle.fill",
                            title: "Total Trades",
                            value: "\(portfolioSummary.totalTrades)",
                            color: .arkadGold,
                            isMainMetric: false
                        )
                    }
                }
            }
            .padding(20)
            .background(
                ZStack {
                    // Base background with arkadgold gradient
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.arkadGold.opacity(0.08),
                                    Color.arkadGold.opacity(0.04),
                                    Color.white
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Subtle pattern overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.arkadGold.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .topTrailing,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.arkadGold.opacity(0.3),
                                Color.arkadGold.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: Color.arkadGold.opacity(0.2),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // Metric card component
    private func metricCard(
        icon: String,
        title: String,
        value: String,
        color: Color,
        isMainMetric: Bool
    ) -> some View {
        VStack(spacing: 8) {
            // Icon with colored background
            Image(systemName: icon)
                .font(isMainMetric ? .title2 : .title3)
                .foregroundColor(color)
                .frame(width: isMainMetric ? 32 : 28, height: isMainMetric ? 32 : 28)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            // Title
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            // Value
            Text(value)
                .font(isMainMetric ? .title3 : .subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isMainMetric ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Profile Tab Selector
struct ProfileTabSelector: View {
    @Binding var selectedTab: ProfileTab
    @Namespace private var tabNamespace
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector with animated indicator
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 8) {
                            // Icon with styling
                            ZStack {
                                // Background circle for active tab
                                if selectedTab == tab {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.arkadGold.opacity(0.2),
                                                    Color.arkadGold.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .matchedGeometryEffect(id: "tabBackground", in: tabNamespace)
                                }
                                
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .medium))
                                    .foregroundColor(selectedTab == tab ? .arkadGold : .textSecondary)
                                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                            }
                            
                            // Tab title
                            Text(tab.title)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundColor(selectedTab == tab ? .arkadGold : .textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // Animated underline indicator
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Rectangle()
                        .fill(selectedTab == tab ? Color.arkadGold : Color.clear)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 1.5)
                        )
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}

// MARK: - Profile Tab Content
struct ProfileTabContent: View {
    let selectedTab: ProfileTab
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    @ObservedObject var postsViewModel: UserPostsViewModel
    @ObservedObject var groupsViewModel: UserGroupsViewModel
    
    var body: some View {
        switch selectedTab {
        case .posts:
            UserPostsTab(postsViewModel: postsViewModel)
        case .trades:
            UserTradesTab(portfolioViewModel: portfolioViewModel)
        case .portfolio:
            UserPortfolioTab(portfolioViewModel: portfolioViewModel)
        case .groups:
            UserGroupsTab(groupsViewModel: groupsViewModel)
        }
    }
}

// MARK: - User Posts Tab
struct UserPostsTab: View {
    @ObservedObject var postsViewModel: UserPostsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if postsViewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.arkadGold)
                    
                    Text("Loading posts...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 60)
            } else if !postsViewModel.errorMessage.isEmpty {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("Failed to Load Posts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(postsViewModel.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        Task {
                            await postsViewModel.refreshPosts()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else if postsViewModel.posts.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("No Posts Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Share your trading insights and market thoughts with the community")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    NavigationLink(destination: HomeView().environmentObject(FirebaseAuthService.shared)) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Create Your First Post")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else {
                // Posts content
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("My Posts (\(postsViewModel.posts.count))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if postsViewModel.posts.count > 6 {
                            NavigationLink(destination: HomeView().environmentObject(FirebaseAuthService.shared)) {
                                Text("View All")
                                    .font(.subheadline)
                                    .foregroundColor(.arkadGold)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Posts grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(postsViewModel.posts.prefix(6), id: \.id) { post in
                            ProfileUserPostCard(post: post)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 100)
        }
        .refreshable {
            await postsViewModel.refreshPosts()
        }
    }
}

// MARK: - User Trades Tab
struct UserTradesTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if portfolioViewModel.trades.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("No Trades Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Start logging your trades to track your performance and share your success with the community")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Your First Trade")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else {
                // Recent trades
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Trades")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(portfolioViewModel.trades.prefix(10)), id: \.id) { trade in
                                ProfileUserTradeCard(trade: trade)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer(minLength: 100)
        }
    }
}

// MARK: - User Portfolio Tab
struct UserPortfolioTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance summary
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        performanceCard(
                            title: "Total Return",
                            value: portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss.asCurrencyWithSign,
                            color: portfolioViewModel.getPortfolioSummaryForProfile().totalProfitLoss >= 0 ? .marketGreen : .marketRed,
                            icon: "dollarsign.circle.fill"
                        )
                        
                        performanceCard(
                            title: "Win Rate",
                            value: String(format: "%.1f%%", portfolioViewModel.getPortfolioSummaryForProfile().winRate),
                            color: portfolioViewModel.getPortfolioSummaryForProfile().winRate >= 50 ? .marketGreen : .marketRed,
                            icon: "target"
                        )
                        
                        performanceCard(
                            title: "Best Trade",
                            value: getBestTradeValue(),
                            color: .marketGreen,
                            icon: "star.fill"
                        )
                        
                        performanceCard(
                            title: "Total Trades",
                            value: "\(portfolioViewModel.getPortfolioSummaryForProfile().totalTrades)",
                            color: .arkadGold,
                            icon: "number.circle.fill"
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Top positions
                if !portfolioViewModel.trades.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Top Performing Positions")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ForEach(Array(getTopPerformingTrades().prefix(5)), id: \.id) { trade in
                            TopPositionCard(trade: trade)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 100)
            }
        }
    }
    
    private func getBestTradeValue() -> String {
        let bestTrade = portfolioViewModel.trades.max { $0.profitLoss < $1.profitLoss }
        return bestTrade?.profitLoss.asCurrencyWithSign ?? "$0"
    }
    
    private func getTopPerformingTrades() -> [Trade] {
        return portfolioViewModel.trades.sorted { $0.profitLoss > $1.profitLoss }
    }
    
    private func performanceCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - User Groups Tab
struct UserGroupsTab: View {
    @ObservedObject var groupsViewModel: UserGroupsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if groupsViewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.arkadGold)
                    
                    Text("Loading groups...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 60)
            } else if !groupsViewModel.errorMessage.isEmpty {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("Failed to Load Groups")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text(groupsViewModel.errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        Task {
                            await groupsViewModel.refreshGroups()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else if groupsViewModel.groups.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(.arkadGold.opacity(0.6))
                    
                    Text("No Groups Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                    
                    Text("Join trading communities to connect with like-minded traders and share strategies")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    NavigationLink(destination: CommunitiesView()) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                            Text("Discover Groups")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 60)
            } else {
                // Groups content
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("My Groups (\(groupsViewModel.groups.count))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        NavigationLink(destination: CommunitiesView()) {
                            Text("Discover More")
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                        }
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(groupsViewModel.groups, id: \.id) { group in
                            ProfileUserGroupCard(group: group)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 100)
        }
        .refreshable {
            await groupsViewModel.refreshGroups()
        }
    }
}

// MARK: - Supporting Card Components
struct ProfileUserPostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.content)
                .font(.caption)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            HStack {
                Image(systemName: "heart")
                    .font(.caption2)
                Text("\(post.likesCount)")
                    .font(.caption2)
                
                Spacer()
                
                Text(formatTimeAgo(post.createdAt))
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ProfileUserTradeCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            // Trade icon
            Image(systemName: trade.isOpen ? "circle" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(trade.isOpen ? .arkadGold : .marketGreen)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.ticker)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if trade.isOpen {
                        Text("OPEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.arkadGold.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                Text("\(trade.quantity) shares @ \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(trade.profitLoss >= 0 ? .marketGreen : .marketRed)
                
                Text(formatShortDate(trade.entryDate))
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TopPositionCard: View {
    let trade: Trade
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.marketGreen.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(trade.ticker.prefix(2))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.marketGreen)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Return: \(String(format: "%.1f", trade.profitLossPercentage))%")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.marketGreen)
                
                Text("\(trade.quantity) shares")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.marketGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ProfileUserGroupCard: View {
    let group: TradingGroup
    
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.arkadGold.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(group.name.prefix(2))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.arkadGold)
                )
            
            VStack(spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.arkadGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Portfolio Details Sheet
struct PortfolioDetailsSheet: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            PortfolioView()
                .environmentObject(portfolioViewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.arkadGold)
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

// MARK: - Supporting Types and View Models
enum ProfileTab: CaseIterable {
    case posts, trades, portfolio, groups
    
    var title: String {
        switch self {
        case .posts: return "Posts"
        case .trades: return "Trades"
        case .portfolio: return "Portfolio"
        case .groups: return "Groups"
        }
    }
    
    var icon: String {
        switch self {
        case .posts: return "square.and.pencil"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "chart.bar.fill"
        case .groups: return "person.3.fill"
        }
    }
}

// MARK: - View Models (Fixed compilation errors)
class UserPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""
    
    func loadUserPosts(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        
        isLoading = true
        errorMessage = "" // Clear previous errors
        
        Task {
            do {
                // Try the Firebase method first, fallback to workaround if index issue
                let userPosts: [Post]
                do {
                    userPosts = try await authService.getUserPosts(userId: userId)
                } catch {
                    print("Firebase getUserPosts failed, using workaround: \(error)")
                    // Fallback to workaround method
                    userPosts = try await getUserPostsWorkaround(userId: userId)
                }
                
                await MainActor.run {
                    self.posts = userPosts
                    self.isLoading = false
                    self.errorMessage = ""
                }
            } catch {
                await MainActor.run {
                    print("Error loading posts: \(error)")
                    self.errorMessage = "Failed to load posts. Please try again."
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    func refreshPosts() async {
        guard !currentUserId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // Try the Firebase method first, fallback to workaround if index issue
            let userPosts: [Post]
            do {
                userPosts = try await authService.getUserPosts(userId: currentUserId)
            } catch {
                print("Firebase getUserPosts failed, using workaround: \(error)")
                // Fallback to workaround method
                userPosts = try await getUserPostsWorkaround(userId: currentUserId)
            }
            
            self.posts = userPosts
            self.errorMessage = ""
        } catch {
            print("Error refreshing posts: \(error)")
            self.errorMessage = "Failed to refresh posts. Please try again."
        }
        
        isLoading = false
    }
    
    // Workaround method using the public FirebaseServices methods
    private func getUserPostsWorkaround(userId: String) async throws -> [Post] {
        do {
            // Use FirebaseServices public method to get all feed posts, then filter
            let allPosts = try await FirebaseServices.shared.getFeedPosts(limit: 200)
            
            // Filter posts by the specific user
            let userPosts = allPosts.filter { $0.authorId == userId }
            
            // Sort locally by date (newest first)
            return userPosts.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Error in getUserPostsWorkaround: \(error)")
            // If even the workaround fails, return empty array instead of throwing
            return []
        }
    }
}

class UserGroupsViewModel: ObservableObject {
    @Published var groups: [TradingGroup] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let authService = FirebaseAuthService.shared
    private var currentUserId: String = ""
    
    func loadUserGroups(userId: String) {
        currentUserId = userId
        guard !userId.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                // Try to get communities from Firebase using the public method
                let communities: [Community]
                do {
                    communities = try await authService.getUserCommunities(userId: userId)
                } catch {
                    print("Firebase getUserCommunities failed: \(error)")
                    // If the method doesn't exist or fails, return empty array
                    communities = []
                }
                
                // Convert communities to TradingGroup
                let tradingGroups = communities.map { community in
                    TradingGroup(
                        id: community.id,
                        name: community.name,
                        description: community.description,
                        memberCount: community.memberCount,
                        isPrivate: false, // You can add this field to Community model if needed
                        imageUrl: nil,
                        category: community.type.displayName,
                        createdAt: community.createdAt
                    )
                }
                
                await MainActor.run {
                    self.groups = tradingGroups
                    self.isLoading = false
                    self.errorMessage = ""
                }
            } catch {
                await MainActor.run {
                    print("Error loading groups: \(error)")
                    self.errorMessage = "Failed to load groups. Please try again."
                    self.isLoading = false
                }
            }
        }
    }
    
    @MainActor
    func refreshGroups() async {
        guard !currentUserId.isEmpty else { return }
        
        isLoading = true
        
        do {
            let communities: [Community]
            do {
                communities = try await authService.getUserCommunities(userId: currentUserId)
            } catch {
                print("Firebase getUserCommunities failed: \(error)")
                communities = []
            }
            
            let tradingGroups = communities.map { community in
                TradingGroup(
                    id: community.id,
                    name: community.name,
                    description: community.description,
                    memberCount: community.memberCount,
                    isPrivate: false,
                    imageUrl: nil,
                    category: community.type.displayName,
                    createdAt: community.createdAt
                )
            }
            
            self.groups = tradingGroups
            self.errorMessage = ""
        } catch {
            print("Error refreshing groups: \(error)")
            self.errorMessage = "Failed to refresh groups. Please try again."
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Models
struct TradingGroup: Identifiable {
    let id: String
    let name: String
    let description: String
    let memberCount: Int
    let isPrivate: Bool
    let imageUrl: String?
    let category: String
    let createdAt: Date
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
