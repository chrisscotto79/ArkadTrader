// File: Core/Profile/Views/ProfileHeaderSection.swift
// Updated Profile Header with Real Profile Images

import SwiftUI

struct ProfileHeaderSection: View {
    let user: User?
    let portfolioSummary: PortfolioSummary
    @Binding var showEditProfile: Bool
    @Binding var showSettings: Bool
    
    // Environment objects and state variables
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    
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
                    
                    // Profile Avatar with enhanced styling - NOW USING REAL IMAGES
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
                        
                        // Main avatar using ProfileImageView
                        ProfileImageView(
                            user: user,
                            size: 110,
                            showBorder: true,
                            borderColor: .white,
                            borderWidth: 5,
                            shadowRadius: 20,
                            shadowOpacity: 0.6,
                            shadowOffset: CGSize(width: 0, height: 10)
                        )
                    }
                    
                    // User stats with enhanced styling - CLICKABLE
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showFollowersList = true
                        }) {
                            statColumn(
                                number: "\(user?.followersCount ?? 0)",
                                label: "Followers"
                            )
                        }
                        .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showFollowingList = true
                        }) {
                            statColumn(
                                number: "\(user?.followingCount ?? 0)",
                                label: "Following"
                            )
                        }
                        .foregroundColor(.primary)
                        
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
                    
                    // FOLLOW BUTTON - Show only if viewing another user's profile
                    if let currentUser = authService.currentUser,
                       let profileUser = user,
                       currentUser.id != profileUser.id {
                        
                        SimpleFollowButton(targetUserId: profileUser.id, targetUsername: profileUser.username)
                            .environmentObject(authService)
                            .padding(.horizontal, 20)
                    }
                    
                    // Action Buttons with enhanced styling
                    HStack(spacing: 15) {
                        if isCurrentUserProfile {
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
        .sheet(isPresented: $showFollowersList) {
            SimpleFollowListView(userId: user?.id ?? "", listType: .followers)
        }
        .sheet(isPresented: $showFollowingList) {
            SimpleFollowListView(userId: user?.id ?? "", listType: .following)
        }
    }
    
    // Helper computed property
    private var isCurrentUserProfile: Bool {
        guard let currentUser = authService.currentUser,
              let profileUser = user else { return true }
        return currentUser.id == profileUser.id
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
}

#Preview {
    ProfileHeaderSection(
        user: .previewUser,
        portfolioSummary: PortfolioSummary(
            totalValue: 10000,
            totalProfitLoss: 1250,
            dayProfitLoss: 125,
            totalTrades: 47,
            winRate: 68.5,
            openPositions: 5
        ),
        showEditProfile: .constant(false),
        showSettings: .constant(false)
    )
    .environmentObject(FirebaseAuthService.shared)
}