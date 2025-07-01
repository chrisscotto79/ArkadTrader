// File: Core/Profile/Views/ProfileView.swift

import SwiftUI
import Foundation

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @State private var showSettings = false
    @State private var selectedTab = 0 // 0 = Overview, 1 = Trades, 2 = Posts
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Profile Header
                    ProfileHeaderView()
                        .environmentObject(authViewModel)
                        .environmentObject(portfolioViewModel)
                    
                    // Tab Selector
                    ProfileTabSelector(selectedTab: $selectedTab)
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case 0:
                        ProfileOverviewTab()
                            .environmentObject(portfolioViewModel)
                    case 1:
                        SimpleProfileTradesTab()
                            .environmentObject(portfolioViewModel)
                    case 2:
                        ProfilePostsTab()
                    default:
                        ProfileOverviewTab()
                            .environmentObject(portfolioViewModel)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(Color.arkadGold)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    List {
                        Section {
                            HStack {
                                Text("Settings")
                                    .font(.headline)
                                Spacer()
                                Button("Done") {
                                    showSettings = false
                                }
                            }
                        }
                        
                        Section {
                            Button("Logout") {
                                authViewModel.logout()
                                showSettings = false
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture & Basic Info
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.arkadGold.opacity(0.3), Color.arkadGold]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 110, height: 110)
                    
                    Text(initials)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color.arkadGold)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Text(authViewModel.currentUser?.fullName ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if authViewModel.currentUser?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color.arkadGold)
                                .font(.title3)
                        }
                    }
                    
                    Text("@\(authViewModel.currentUser?.username ?? "username")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Subscription Badge
                    HStack {
                        Image(systemName: subscriptionIcon)
                            .font(.caption)
                        Text(authViewModel.currentUser?.subscriptionTier.displayName ?? "Basic")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(subscriptionColor.opacity(0.15))
                    .foregroundColor(subscriptionColor)
                    .cornerRadius(12)
                }
                
                // Bio
                if let bio = authViewModel.currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("New trader on ArkadTrader 📈")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // Stats Row - Real Data
            HStack(spacing: 0) {
                ProfileStatView(
                    title: "Following",
                    value: "\(authViewModel.currentUser?.followingCount ?? 0)",
                    color: Color.arkadGold
                )
                .frame(maxWidth: .infinity)
                
                ProfileStatView(
                    title: "Followers",
                    value: "\(authViewModel.currentUser?.followersCount ?? 0)",
                    color: Color.arkadGold
                )
                .frame(maxWidth: .infinity)
                
                ProfileStatView(
                    title: "Trades",
                    value: "\(portfolioViewModel.trades.count)",
                    color: Color.arkadGold
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Quick Action Buttons
            HStack(spacing: 12) {
                NavigationLink(destination: EditProfileView()) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Edit Profile")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.arkadGold)
                    .cornerRadius(8)
                }
                
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.arkadGold)
                        .frame(width: 44, height: 44)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showShareSheet) {
            ShareProfileSheet()
                .environmentObject(authViewModel)
                .environmentObject(portfolioViewModel)
        }
    }
    
    private var initials: String {
        guard let user = authViewModel.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first : nil
        
        if let lastInitial = lastInitial {
            return String(firstInitial) + String(lastInitial)
        } else {
            return String(firstInitial)
        }
    }
    
    private var subscriptionColor: Color {
        switch authViewModel.currentUser?.subscriptionTier {
        case .basic: return Color.gray
        case .pro: return Color.arkadGold
        case .elite: return Color.arkadBlack
        case .none: return Color.gray
        }
    }
    
    private var subscriptionIcon: String {
        switch authViewModel.currentUser?.subscriptionTier {
        case .basic: return "star"
        case .pro: return "star.fill"
        case .elite: return "crown.fill"
        case .none: return "star"
        }
    }
}

// MARK: - Profile Tab Selector
struct ProfileTabSelector: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Overview", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            TabButton(title: "Trades", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            TabButton(title: "Posts", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? Color.arkadBlack : Color.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.arkadGold : Color.clear)
                .cornerRadius(8)
        }
    }
}

// MARK: - Profile Stat View
struct ProfileStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Overview Tab
struct ProfileOverviewTab: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Performance Dashboard
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Performance")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("All Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                // Performance Cards Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 12) {
                    PerformanceCard(
                        title: "Total P&L",
                        value: portfolioViewModel.portfolio?.totalProfitLoss.asCurrencyWithSign ?? "$0.00",
                        color: (portfolioViewModel.portfolio?.totalProfitLoss ?? 0) >= 0 ? .marketGreen : .marketRed,
                        icon: "dollarsign.circle"
                    )
                    
                    PerformanceCard(
                        title: "Win Rate",
                        value: String(format: "%.1f%%", portfolioViewModel.portfolio?.winRate ?? 0),
                        color: .arkadGold,
                        icon: "target"
                    )
                    
                    PerformanceCard(
                        title: "Total Trades",
                        value: "\(portfolioViewModel.trades.count)",
                        color: .arkadGold,
                        icon: "chart.bar"
                    )
                    
                    PerformanceCard(
                        title: "Open Positions",
                        value: "\(portfolioViewModel.trades.filter { $0.isOpen }.count)",
                        color: .marketGreen,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .padding(.horizontal)
            }
            
            // Recent Activity
            if !portfolioViewModel.trades.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(portfolioViewModel.trades.prefix(3), id: \.id) { trade in
                            TradeRowView(trade: trade, style: .compact)
                                .padding(.horizontal)
                        }
                    }
                }
            } else {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Start Your Trading Journey")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text("Add your first trade to see your performance metrics here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Simplified Trades Tab (avoiding conflicts)
struct SimpleProfileTradesTab: View {
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            if !portfolioViewModel.trades.isEmpty {
                Text("Trading Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                Text("\(portfolioViewModel.trades.count) total trades")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                // Simple trades list
                LazyVStack(spacing: 8) {
                    ForEach(portfolioViewModel.trades.prefix(5), id: \.id) { trade in
                        TradeRowView(trade: trade, style: .standard)
                            .padding(.horizontal)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Trades Yet")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 40)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Posts Tab
struct ProfilePostsTab: View {
    var body: some View {
        VStack(spacing: 24) {
            // Posts Stats
            HStack(spacing: 0) {
                PostStatCard(title: "Posts", value: "0", color: .arkadGold)
                    .frame(maxWidth: .infinity)
                PostStatCard(title: "Likes", value: "0", color: .marketGreen)
                    .frame(maxWidth: .infinity)
                PostStatCard(title: "Comments", value: "0", color: .arkadGold)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Empty State for Posts
            VStack(spacing: 16) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No Posts Yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text("Share your trading insights and connect with the community")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
        .padding(.top, 20)
    }
}

// MARK: - Share Profile Sheet
struct ShareProfileSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Share your profile with friends!")
                    .font(.headline)
                    .padding()
                
                Button("Share via System") {
                    // System share functionality
                    let shareText = "Check out my trading profile on ArkadTrader! @\(authViewModel.currentUser?.username ?? "trader")"
                    let activityController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityController, animated: true)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.arkadGold)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct PerformanceCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct SimpleTradingStatCard: View {
    let title: String
    let value: String
    let color: Color
    let subtitle: String?
    
    init(title: String, value: String, color: Color, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.color = color
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PostStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
