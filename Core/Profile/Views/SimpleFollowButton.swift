// File: Core/Profile/Views/SimpleFollowButton.swift
// Follow/unfollow button and the simple follower list it opens.

import SwiftUI

// MARK: - Simple Follow Button (Minimal Version)
struct SimpleFollowButton: View {
    let targetUserId: String
    let targetUsername: String
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var debugInfo = ""
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                Task {
                    await toggleFollow()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                            .font(.subheadline)
                    }
                    
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isFollowing ? .primary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
                        .shadow(color: isFollowing ? Color.clear : Color.arkadGold.opacity(0.5), radius: 10, x: 0, y: 5)
                )
            }
            .disabled(isLoading)

        }
        .onAppear {
            Task {
                await checkFollowStatus()
            }
        }
        .alert("Follow Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleFollow() async {
        // Enhanced debugging and error handling
        print("🔄 toggleFollow() called")
        print("📋 targetUserId: \(targetUserId)")
        print("👤 targetUsername: \(targetUsername)")
        
        guard let currentUserId = authService.currentUser?.id else {
            await MainActor.run {
                errorMessage = "Not authenticated. Please sign in again."
                showError = true
                debugInfo = "❌ No current user"
            }
            print("❌ No current user found")
            return
        }
        
        guard !targetUserId.isEmpty else {
            await MainActor.run {
                errorMessage = "Invalid user ID"
                showError = true
                debugInfo = "❌ Empty target user ID"
            }
            print("❌ Target user ID is empty")
            return
        }
        
        guard currentUserId != targetUserId else {
            await MainActor.run {
                errorMessage = "Cannot follow yourself"
                showError = true
                debugInfo = "❌ Cannot follow self"
            }
            print("❌ Trying to follow self")
            return
        }
        
        print("✅ Current user: \(currentUserId)")
        print("🔄 Starting follow operation...")
        
        await MainActor.run {
            isLoading = true
            debugInfo = "🔄 Processing..."
        }
        
        do {
            if isFollowing {
                print("👋 Unfollowing user...")
                try await authService.unfollowUser(userId: targetUserId, followerId: currentUserId)
                print("✅ Unfollow successful")
            } else {
                print("👍 Following user...")
                try await authService.followUser(userId: targetUserId, followerId: currentUserId)
                print("✅ Follow successful")
            }
            
            await MainActor.run {
                isFollowing.toggle()
                debugInfo = isFollowing ? "✅ Following!" : "✅ Unfollowed!"
                
                // Clear debug info after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    debugInfo = ""
                }
            }
            
        } catch {
            print("❌ Follow error: \(error)")
            print("📋 Error details: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = "Follow failed: \(error.localizedDescription)"
                showError = true
                debugInfo = "❌ Error: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func checkFollowStatus() async {
        print("🔍 Checking follow status...")
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ No current user for follow status check")
            await MainActor.run {
                debugInfo = "❌ Not authenticated"
            }
            return
        }
        
        guard !targetUserId.isEmpty else {
            print("❌ Empty target user ID for follow status check")
            return
        }
        
        print("🔍 Checking if \(currentUserId) follows \(targetUserId)")
        
        do {
            let followStatus = try await authService.isFollowing(userId: currentUserId, targetUserId: targetUserId)
            print("✅ Follow status result: \(followStatus)")
            
            await MainActor.run {
                isFollowing = followStatus
                debugInfo = followStatus ? "Already following" : "Not following"
                
                // Clear debug info after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    debugInfo = ""
                }
            }
        } catch {
            print("❌ Error checking follow status: \(error)")
            await MainActor.run {
                debugInfo = "❌ Status check failed"
            }
        }
    }
}

// MARK: - Simple Follow List View (Minimal Version)
struct SimpleFollowListView: View {
    let userId: String
    let listType: ListType
    
    @State private var users: [User] = []
    @State private var isLoading = true
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    enum ListType {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack {
                        Text("No \(listType.title.lowercased()) yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(users) { user in
                            SimpleUserRow(user: user)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadUsers()
                }
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        
        do {
            let userIds: Set<String>
            
            switch listType {
            case .followers:
                userIds = try await authService.getUserFollowers(userId: userId)
            case .following:
                userIds = try await authService.getUserFollowing(userId: userId)
            }
            
            // Fetch user details
            var fetchedUsers: [User] = []
            for id in userIds {
                if let user = try await authService.getUserById(userId: id) {
                    fetchedUsers.append(user)
                }
            }
            
            users = fetchedUsers.sorted { $0.username < $1.username }
            
        } catch {
            print("Error loading users: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Simple User Row (Minimal Version)
struct SimpleUserRow: View {
    let user: User
    
    var body: some View {
        HStack {
            // Simple initial circle instead of image
            Circle()
                .fill(Color.arkadGold)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
