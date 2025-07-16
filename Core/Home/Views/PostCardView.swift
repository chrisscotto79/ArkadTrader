//
//  PostCardView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/16/25.
//


import SwiftUI

struct PostCardView: View {
    let post: Post
    @State private var isLiked = false
    @State private var showComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                AsyncImage(url: URL(string: "https://avatar.iran.liara.run/username?username=\(post.authorUsername)")) { image in
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
                    Text("@\(post.authorUsername)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Post type badge
                Text(post.postType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(postTypeColor.opacity(0.1))
                    .foregroundColor(postTypeColor)
                    .cornerRadius(12)
            }
            
            // Content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action buttons
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        isLiked.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        Text("\(post.likesCount)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                Button(action: {
                    showComments.toggle()
                }) {
                    HStack {
                        Image(systemName: "bubble.left")
                        Text("\(post.commentsCount)")
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
                
                Spacer()
                
                Button(action: {
                    // Handle share
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showComments) {
            CommentsView(postId: post.id)
        }
    }
    
    private var postTypeColor: Color {
        switch post.postType {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .orange
        }
    }
}
