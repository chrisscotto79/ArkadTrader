//
//  SupportingViews.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//

// File: Core/Home/Views/Components/SupportingViews.swift
// Supporting views for HomeView components

import SwiftUI

// MARK: - FilterChip
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .arkadGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.arkadGold : Color.arkadGold.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.arkadGold, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - EmptyFollowingView
struct EmptyFollowingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("No Following Activity")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start following other traders to see their posts and activities here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Discover Users") {
                // TODO: Navigate to search/discover
            }
            .foregroundColor(.arkadGold)
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FollowingContentItem
enum FollowingContentItem: Identifiable {
    case post(Post)
    case activity(FollowingActivity)
    
    var id: String {
        switch self {
        case .post(let post): return "post_\(post.id)"
        case .activity(let activity): return "activity_\(activity.id)"
        }
    }
}

// MARK: - SimpleUserProfileView (placeholder)
struct SimpleUserProfileView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 20) {
            AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.arkadGold.opacity(0.3))
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                    )
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text(user.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            HStack(spacing: 30) {
                VStack {
                    Text("\(user.followersCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(user.followingCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Simple Loading Views
struct SimpleLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.arkadGold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SimpleLoadMoreButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("Load More")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: "arrow.down.circle")
                    .font(.subheadline)
            }
            .foregroundColor(.arkadGold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
