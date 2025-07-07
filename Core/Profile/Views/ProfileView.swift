// File: Core/Profile/Views/ProfileView.swift
// Enhanced Profile View with comprehensive portfolio integration

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedTab: ProfileTab = .overview
    @State private var showPortfolioDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
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
                        portfolioViewModel: portfolioViewModel
                    )
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await refreshProfile()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showSettings) {
            EnhancedSettingsView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showPortfolioDetails) {
            PortfolioDetailsSheet()
                .environmentObject(portfolioViewModel)
        }
        .onAppear {
            portfolioViewModel.loadPortfolioData()
        }
    }
    
    @MainActor
    private func refreshProfile() async {
        portfolioViewModel.refreshPortfolio()
    }
}

// MARK: - Enhanced Profile Header
struct ProfileHeaderSection: View {
    let user: User?
    let portfolioSummary: PortfolioSummary
    @Binding var showEditProfile: Bool
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Top navigation
            HStack {
                VStack(alignment: .leading) {
                    Text(user?.fullName ?? "User")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("@\(user?.username ?? "username")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if user?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "plus.app")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Profile Picture and Stats Row
            HStack(spacing: 30) {
                // Profile Picture
                ProfileAvatarView(user: user, size: 80)
                
                // Stats
                HStack(spacing: 25) {
                    StatColumn(
                        number: "\(user?.followersCount ?? 0)",
                        label: "Followers"
                    )
                    
                    StatColumn(
                        number: "\(user?.followingCount ?? 0)",
                        label: "Following"
                    )
                    
                    StatColumn(
                        number: "\(portfolioSummary.totalTrades)",
                        label: "Trades"
                    )
                    
                    StatColumn(
                        number: String(format: "%.1f%%", portfolioSummary.winRate),
                        label: "Win Rate"
                    )
                }
            }
            .padding(.horizontal)
            
            // Bio Section
            if let bio = user?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { showEditProfile = true }) {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    shareProfile()
                }) {
                    Text("Share Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
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
}

// MARK: - Portfolio Performance Banner
struct PortfolioPerformanceBanner: View {
    let portfolioSummary: PortfolioSummary
    @Binding var showPortfolioDetails: Bool
    
    var body: some View {
        Button(action: { showPortfolioDetails = true }) {
            VStack(spacing: 12) {
                HStack {
                    Text("Portfolio Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Total Value")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(portfolioSummary.totalValue.asCurrency)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total P&L")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(portfolioSummary.totalProfitLoss.asCurrencyWithSign)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(portfolioSummary.totalProfitLoss >= 0 ? .green : .red)
                    }
                    
                    VStack(alignment: .trailing) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(portfolioSummary.dayProfitLoss.asCurrencyWithSign)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(portfolioSummary.dayProfitLoss >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// MARK: - Profile Tab Selector
struct ProfileTabSelector: View {
    @Binding var selectedTab: ProfileTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Profile Tab Content
struct ProfileTabContent: View {
    let selectedTab: ProfileTab
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        switch selectedTab {
        case .overview:
            ProfileOverviewTab(portfolioViewModel: portfolioViewModel)
        case .trades:
            ProfileTradesTab()
                .environmentObject(portfolioViewModel)
        case .analytics:
            ProfileAnalyticsTab(portfolioViewModel: portfolioViewModel)
        case .achievements:
            ProfileAchievementsTab(portfolioViewModel: portfolioViewModel)
        }
    }
}

// MARK: - Profile Overview Tab
struct ProfileOverviewTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Quick Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickStatCard(
                    title: "Open Positions",
                    value: "\(portfolioViewModel.portfolio?.openPositions ?? 0)",
                    icon: "clock.fill",
                    color: .blue
                )
                
                QuickStatCard(
                    title: "Closed Trades",
                    value: "\(portfolioViewModel.trades.filter { !$0.isOpen }.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                QuickStatCard(
                    title: "Best Trade",
                    value: portfolioViewModel.portfolioAnalytics?.bestTrade?.profitLoss.asCurrency ?? "$0",
                    icon: "trophy.fill",
                    color: .yellow
                )
                
                QuickStatCard(
                    title: "Profit Factor",
                    value: String(format: "%.2f", portfolioViewModel.portfolioAnalytics?.profitFactor ?? 0),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            // Recent Trades
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Recent Trades")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    NavigationLink(destination: PortfolioView().environmentObject(portfolioViewModel)) {
                        Text("View All")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if portfolioViewModel.trades.isEmpty {
                    EmptyTradesView()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(portfolioViewModel.trades.prefix(5)), id: \.id) { trade in
                                RecentTradeCard(trade: trade)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer(minLength: 50)
        }
        .padding(.top, 20)
    }
}

// MARK: - Profile Analytics Tab
struct ProfileAnalyticsTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let analytics = portfolioViewModel.portfolioAnalytics {
                    // Performance Metrics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Performance Metrics")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            AnalyticsCard(title: "Total Return", value: analytics.totalReturn.asCurrencyWithSign, color: analytics.totalReturn >= 0 ? .green : .red)
                            AnalyticsCard(title: "Return %", value: analytics.totalReturnPercentage.asPercentageWithSign, color: analytics.totalReturnPercentage >= 0 ? .green : .red)
                            AnalyticsCard(title: "Avg Hold Time", value: "\(Int(analytics.averageHoldTime)) days", color: .blue)
                            AnalyticsCard(title: "Avg Trade Size", value: analytics.averageTradeSize.asCurrency, color: .blue)
                            AnalyticsCard(title: "Sharpe Ratio", value: String(format: "%.2f", analytics.sharpeRatio), color: .blue)
                            AnalyticsCard(title: "Max Drawdown", value: String(format: "%.1f%%", analytics.maxDrawdown), color: .red)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Best & Worst Trades
                    if let bestTrade = analytics.bestTrade {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Best Trade")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            TradeHighlightCard(trade: bestTrade, type: .best)
                                .padding(.horizontal)
                        }
                    }
                    
                    if let worstTrade = analytics.worstTrade {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Worst Trade")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            TradeHighlightCard(trade: worstTrade, type: .worst)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    Text("No analytics available yet")
                        .foregroundColor(.gray)
                        .padding(.top, 50)
                }
                
                Spacer(minLength: 50)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Profile Achievements Tab
struct ProfileAchievementsTab: View {
    @ObservedObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(generateAchievements(), id: \.id) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .padding(.top, 20)
    }
    
    private func generateAchievements() -> [Achievement] {
        let totalTrades = portfolioViewModel.trades.count
        let totalPL = portfolioViewModel.portfolio?.totalProfitLoss ?? 0
        let winRate = portfolioViewModel.portfolio?.winRate ?? 0
        let openPositions = portfolioViewModel.portfolio?.openPositions ?? 0
        
        return [
            Achievement(id: "first_trade", title: "First Trade", description: "Made your first trade", icon: "star.fill", isUnlocked: totalTrades > 0),
            Achievement(id: "profit_maker", title: "Profit Maker", description: "Earned $1000 in profits", icon: "dollarsign.circle.fill", isUnlocked: totalPL >= 1000),
            Achievement(id: "active_trader", title: "Active Trader", description: "Complete 10 trades", icon: "chart.line.uptrend.xyaxis", isUnlocked: totalTrades >= 10),
            Achievement(id: "consistent_winner", title: "Consistent Winner", description: "Achieve 70% win rate", icon: "trophy.fill", isUnlocked: winRate >= 70.0 && totalTrades >= 5),
            Achievement(id: "portfolio_builder", title: "Portfolio Builder", description: "Have 5 open positions", icon: "building.columns.fill", isUnlocked: openPositions >= 5),
            Achievement(id: "big_winner", title: "Big Winner", description: "Earn $10,000 in profits", icon: "crown.fill", isUnlocked: totalPL >= 10000)
        ]
    }
}

// MARK: - Supporting Views

struct ProfileAvatarView: View {
    let user: User?
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.blue)
        }
    }
    
    private var initials: String {
        guard let fullName = user?.fullName else { return "U" }
        let names = fullName.split(separator: " ")
        let first = names.first?.first ?? Character("U")
        let last = names.count > 1 ? names.last?.first : nil
        return String(first) + (last != nil ? String(last!) : "")
    }
}

struct StatColumn: View {
    let number: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct TradeHighlightCard: View {
    let trade: Trade
    let type: TradeHighlightType
    
    enum TradeHighlightType {
        case best, worst
        
        var color: Color {
            switch self {
            case .best: return .green
            case .worst: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .best: return "arrow.up.circle.fill"
            case .worst: return "arrow.down.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(trade.quantity) shares")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(type.color)
                
                Text("\(trade.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", trade.profitLossPercentage))%")
                    .font(.caption)
                    .foregroundColor(type.color)
            }
        }
        .padding()
        .background(type.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RecentTradeCard: View {
    let trade: Trade
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trade.ticker)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if trade.isOpen {
                    Text("OPEN")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Text("\(trade.quantity) shares")
                .font(.caption)
                .foregroundColor(.gray)
            
            if trade.isOpen {
                Text("Entry: \(trade.entryPrice.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Text(trade.profitLoss.asCurrencyWithSign)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trade.profitLoss >= 0 ? .green : .red)
            }
        }
        .padding()
        .frame(width: 120, height: 80)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct EmptyTradesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No trades yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            NavigationLink(destination: PortfolioView()) {
                Text("Add Your First Trade")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.largeTitle)
                .foregroundColor(achievement.isUnlocked ? .blue : .gray)
            
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(achievement.isUnlocked ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
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
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Supporting Types
enum ProfileTab: CaseIterable {
    case overview, trades, analytics, achievements
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .trades: return "Trades"
        case .analytics: return "Analytics"
        case .achievements: return "Awards"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .analytics: return "chart.bar.fill"
        case .achievements: return "trophy.fill"
        }
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}

#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
