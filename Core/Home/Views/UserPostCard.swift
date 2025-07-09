// File: Core/Home/Views/UserPostCard.swift
// Simple User Post Card component

import SwiftUI

struct UserPostCard: View {
    let post: Post
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var isLiked = false
    @State private var likesCount: Int
    
    init(post: Post, homeViewModel: HomeViewModel) {
        self.post = post
        self.homeViewModel = homeViewModel
        self._likesCount = State(initialValue: post.likesCount)
        self._isLiked = State(initialValue: homeViewModel.likedPosts.contains(post.id))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // User Header
            HStack(spacing: 12) {
                // Profile Avatar
                Circle()
                    .fill(Color.arkadGold.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.authorUsername.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.arkadGold)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(post.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(formatDate(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Post type badge
                if post.postType != .text {
                    Text(post.postType.displayName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(postTypeColor(for: post.postType))
                        .cornerRadius(8)
                }
            }
            
            // Post Content
            Text(post.content)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
            
            // Engagement Section
            HStack(spacing: 24) {
                // Like button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                        likesCount += isLiked ? 1 : -1
                        homeViewModel.toggleLike(for: post.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        
                        Text("\(likesCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isLiked ? .red : .gray)
                    }
                }
                
                // Comment button
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .foregroundColor(.gray)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                // Share button
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                        
                        Text("Share")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: {
                    homeViewModel.toggleBookmark(for: post.id)
                }) {
                    Image(systemName: homeViewModel.bookmarkedPosts.contains(post.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(homeViewModel.bookmarkedPosts.contains(post.id) ? .arkadGold : .gray)
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func postTypeColor(for type: PostType) -> Color {
        switch type {
        case .text: return .clear
        case .tradeResult: return .green
        case .marketAnalysis: return .blue
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    let samplePost = Post(content: "Just made a great trade on AAPL! 📈", authorId: "1", authorUsername: "trader1")
    
    UserPostCard(post: samplePost, homeViewModel: HomeViewModel())
        .padding()
}
