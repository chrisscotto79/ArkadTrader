//
//  UsersListDebugView.swift
//  ArkadTrader
//
//  Debug view for testing follow functionality by browsing users - FIXED
//

import SwiftUI

struct UsersListDebugView: View {
    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var selectedUser: User?
    @State private var showOtherUserProfile = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No other users found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Create another test account to test following")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(users) { user in
                        UserRowWithFollowButton(user: user) {
                            selectedUser = user
                            showOtherUserProfile = true
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Test Follow Feature")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadUsers()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showOtherUserProfile) {
                if let selectedUser = selectedUser {
                    OtherUserProfileView(user: selectedUser)
                        .environmentObject(authService)
                }
            }
        }
        .onAppear {
            Task {
                await loadUsers()
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        
        // Create mock users using proper User initializer
        users = createMockUsers()
        
        isLoading = false
    }
    
    private func createMockUsers() -> [User] {
        let currentUserId = authService.currentUser?.id ?? ""
        
        // Create users with proper initializer, then set additional properties
        var user1 = User(
            id: "user1",
            email: "john@example.com",
            username: "johntrader",
            fullName: "John Trader"
        )
        user1.bio = "Professional day trader with 5+ years experience. Love crypto and stocks!"
        user1.followersCount = 245
        user1.followingCount = 180
        user1.totalProfitLoss = 15420.50
        user1.winRate = 68.5
        user1.isVerified = true
        user1.subscriptionTier = .pro
        
        var user2 = User(
            id: "user2",
            email: "sarah@example.com",
            username: "sarahg",
            fullName: "Sarah Goldman"
        )
        user2.bio = "Swing trader focused on tech stocks. $AAPL $MSFT specialist 📈"
        user2.followersCount = 892
        user2.followingCount = 120
        user2.totalProfitLoss = 32150.75
        user2.winRate = 72.3
        user2.isVerified = true
        user2.subscriptionTier = .elite
        
        var user3 = User(
            id: "user3",
            email: "mike@example.com",
            username: "mikechen",
            fullName: "Mike Chen"
        )
        user3.bio = "Options trader and market analyst. Teaching others to trade smarter 🎯"
        user3.followersCount = 1520
        user3.followingCount = 95
        user3.totalProfitLoss = 48900.25
        user3.winRate = 75.1
        user3.isVerified = false
        user3.subscriptionTier = .pro
        
        var user4 = User(
            id: "user4",
            email: "emma@example.com",
            username: "emmaw",
            fullName: "Emma Wilson"
        )
        user4.bio = "Crypto enthusiast | DeFi researcher | Long-term HODLer 🚀"
        user4.followersCount = 680
        user4.followingCount = 340
        user4.totalProfitLoss = 22800.00
        user4.winRate = 61.2
        user4.isVerified = false
        user4.subscriptionTier = .basic
        
        var user5 = User(
            id: "user5",
            email: "alex@example.com",
            username: "alexr",
            fullName: "Alex Rodriguez"
        )
        user5.bio = "Forex trader with global market expertise. USD/EUR specialist 💱"
        user5.followersCount = 425
        user5.followingCount = 200
        user5.totalProfitLoss = 18750.50
        user5.winRate = 66.8
        user5.isVerified = false
        user5.subscriptionTier = .basic
        
        return [user1, user2, user3, user4, user5].filter { $0.id != currentUserId }
    }
}

struct UserRowWithFollowButton: View {
    let user: User
    let onTap: () -> Void
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile image placeholder
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(userInitials)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.fullName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(user.followersCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("followers")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var userInitials: String {
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

#Preview {
    UsersListDebugView()
        .environmentObject(FirebaseAuthService.shared)
}
