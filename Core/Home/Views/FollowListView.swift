//
//  FollowListView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


import SwiftUI

struct FollowListView: View {
    let userId: String
    let listType: ListType
    
    @State private var users: [User] = []
    @State private var isLoading = true
    @EnvironmentObject var authService: FirebaseAuthService
    
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
            List {
                ForEach(users) { user in
                    UserRowView(user: user)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadUsers()
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

struct UserRowView: View {
    let user: User
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(user.username)")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.fullName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            FollowButton(targetUserId: user.id, targetUsername: user.username)
        }
        .padding(.vertical, 4)
    }
}