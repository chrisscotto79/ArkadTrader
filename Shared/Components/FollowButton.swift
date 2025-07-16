//
//  FollowButton.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//

import SwiftUI

struct FollowButton: View {
    let targetUserId: String
    let targetUsername: String
    @State private var isFollowing = false
    @State private var isLoading = false
    
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        Button(action: {
            Task {
                await toggleFollow()
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                }
                
                Text(isFollowing ? "Following" : "Follow")
                    .fontWeight(.semibold)
            }
            .foregroundColor(isFollowing ? .primary : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFollowing ? Color.gray.opacity(0.2) : Color.arkadGold)
            )
        }
        .disabled(isLoading)
        .onAppear {
            Task {
                await checkFollowStatus()
            }
        }
    }
    
    private func toggleFollow() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        do {
            if isFollowing {
                try await authService.unfollowUser(userId: targetUserId, followerId: currentUserId)
            } else {
                try await authService.followUser(userId: targetUserId, followerId: currentUserId)
            }
            
            isFollowing.toggle()
            
        } catch {
            print("Error toggling follow: \(error)")
        }
        
        isLoading = false
    }
    
    private func checkFollowStatus() async {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        do {
            isFollowing = try await authService.isFollowing(userId: currentUserId, targetUserId: targetUserId)
        } catch {
            print("Error checking follow status: \(error)")
        }
    }
}

