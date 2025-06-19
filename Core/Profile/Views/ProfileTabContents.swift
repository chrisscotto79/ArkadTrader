// File: Core/Profile/Views/ProfileView.swift

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @State private var showSettings = false
    @State private var selectedTab = 0 // 0 = Overview, 1 = Trades, 2 = Posts
    
    var body: some View {
        NavigationView {
            ScrollView {
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
                        ProfileTradesTab()
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
                            .foregroundColor(.arkadGold)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                MainSettingsView()
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var portfolioViewModel: PortfolioViewModel
    
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
                        .foregroundColor(.arkadGold)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Text(authViewModel.currentUser?.fullName ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if authViewModel.currentUser?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.arkadGold)
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
                    color: .arkadGold
                )
                .frame(maxWidth: .infinity)
                
                ProfileStatView(
                    title: "Followers",
                    value: "\(authViewModel.currentUser?.followersCount ?? 0)",
                    color: .arkadGold
                )
                .frame(maxWidth: .infinity)
                
                ProfileStatView(
                    title: "Trades",
                    value: "\(portfolioViewModel.trades.count)",
                    color: .arkadGold
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Quick Action Buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Follow")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.arkadGold)
                    .cornerRadius(8)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "message")
                        Text("Message")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
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
    }
    
    private var initials: String {
        guard let user = authViewModel.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let firstInitial = names.first?.first ?? Character("U")
        let lastInitial = names.count > 1 ? names.last?.first ?? Character("") : Character("")
        return String(firstInitial) + String(lastInitial)
    }
    
    private var subscriptionColor: Color {
        switch authViewModel.currentUser?.subscriptionTier {
        case .basic: return .gray
        case .pro: return .arkadGold
        case .elite: return .arkadBlack
        case .none: return .gray
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
                .foregroundColor(isSelected ? .arkadBlack : .gray)
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

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
