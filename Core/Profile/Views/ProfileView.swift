// File: Core/Profile/Views/ProfileView.swift
// Fixed Profile View - simple and clean, no missing dependencies

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

// MARK: - Profile Header Section
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
                                .foregroundColor(Color.blue)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "plus.app")
                            .font(.title2)
                            .foregroundColor(Color.blue)
                    }
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(Color.blue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Profile Picture and Stats Row
            HStack(spacing: 30) {
                // Profile Picture
                simpleProfileAvatar(user: user, size: 80)
                
                // Stats
                HStack(spacing: 25) {
                    simpleStatColumn(
                        number: "\(user?.followersCount ?? 0)",
                        label: "Followers"
                    )
                    
                    simpleStatColumn(
                        number: "\(user?.followingCount ?? 0)",
                        label: "Following"
                    )
                    
                    simpleStatColumn(
                        number: "\(portfolioSummary.totalTrades)",
                        label: "Trades"
                    )
                    
                    simpleStatColumn(
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
                        .foregroundColor(Color.blue)
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
    
    // Simple inline components
    private func simpleProfileAvatar(user: User?, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: size, height: size)
            
            Text(getInitials(user: user))
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(Color.blue)
        }
    }
    
    private func simpleStatColumn(number: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private func getInitials(user: User?) -> String {
        guard let user = user else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
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
                    .foregroundColor(selectedTab == tab ? Color.blue : .gray)
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

#Preview {
    ProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
