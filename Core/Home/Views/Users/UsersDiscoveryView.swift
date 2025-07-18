//
//  UsersDiscoveryView.swift
//  ArkadTrader
//
//  CREATE THIS NEW FILE: Core/Home/Views/UsersDiscoveryView.swift
//  Production-ready user discovery with real Firebase data
//

import SwiftUI

struct UsersDiscoveryView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var showOtherUserProfile = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                Group {
                    if isLoading {
                        ProgressView("Discovering users...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if users.isEmpty && !searchText.isEmpty {
                        EmptySearchView(searchText: searchText)
                    } else if users.isEmpty {
                        EmptyDiscoveryView()
                    } else {
                        usersList
                    }
                }
            }
            .navigationTitle("Discover Traders")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
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
                await loadInitialUsers()
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search traders by username...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 16)
        .onChange(of: searchText) { _, newValue in
            Task {
                await searchUsers(query: newValue)
            }
        }
    }
    
    private var usersList: some View {
        List(users) { user in
            UserDiscoveryRow(user: user) {
                selectedUser = user
                showOtherUserProfile = true
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadInitialUsers()
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadInitialUsers() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            // Search for users with common usernames to discover traders
            let commonSearches = ["trader", "invest", "bull", "bear", "crypto", "stock"]
            var allUsers: [User] = []
            
            for searchTerm in commonSearches {
                let foundUsers = try await authService.searchUsers(query: searchTerm)
                allUsers.append(contentsOf: foundUsers)
            }
            
            // Remove duplicates and current user
            let currentUserId = authService.currentUser?.id ?? ""
            let uniqueUsers = Array(Set(allUsers.map { $0.id }))
                .compactMap { userId in allUsers.first { $0.id == userId } }
                .filter { $0.id != currentUserId }
                .sorted { $0.followersCount > $1.followersCount }
            
            users = Array(uniqueUsers.prefix(50)) // Limit to 50 users
            
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    private func searchUsers(query: String) async {
        guard !query.isEmpty else {
            await loadInitialUsers()
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let searchResults = try await authService.searchUsers(query: query)
            let currentUserId = authService.currentUser?.id ?? ""
            users = searchResults.filter { $0.id != currentUserId }
            
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - User Discovery Row
struct UserDiscoveryRow: View {
    let user: User
    let onTap: () -> Void
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile avatar
                Circle()
                    .fill(tierColor)
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
                        
                        Spacer()
                        
                        Text(user.subscriptionTier.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tierColor.opacity(0.1))
                            .foregroundColor(tierColor)
                            .cornerRadius(4)
                    }
                    
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Stats row
                    HStack(spacing: 16) {
                        statLabel("\(user.followersCount)", "followers")
                        statLabel(user.totalProfitLoss.asCurrency, "P&L")
                        statLabel(String(format: "%.1f%%", user.winRate), "win rate")
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Follow button
                SimpleFollowButton(
                    targetUserId: user.id,
                    targetUsername: user.username
                )
                .scaleEffect(0.8)
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
    
    private func statLabel(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
    
    private var tierColor: Color {
        switch user.subscriptionTier {
        case .basic: return .gray
        case .pro: return .blue
        case .elite: return .arkadGold
        }
    }
}

// MARK: - Empty States
struct EmptyDiscoveryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Discover Traders")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Search for traders by username or explore popular users in the community")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Try searching for keywords like 'crypto', 'stocks', or 'trader'")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

struct EmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No traders found")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("No users found for '\(searchText)'")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try a different username or search term")
                .font(.caption)
                .foregroundColor(.arkadDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    UsersDiscoveryView()
        .environmentObject(FirebaseAuthService.shared)
}
