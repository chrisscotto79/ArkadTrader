//
//  SocialFeedView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/6/25.
//


// File: Core/Home/Views/SocialFeedView.swift
// Simplified Social Feed View

import SwiftUI

struct SocialFeedView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var posts: [Post] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(posts) { post in
                    PostCardView(post: post)
                }
            }
            .padding()
        }
        .onAppear {
            loadPosts()
        }
    }
    
    private func loadPosts() {
        Task {
            do {
                posts = try await authService.getFeedPosts()
            } catch {
                print("Error loading posts: \(error)")
            }
        }
    }
}

struct PostCardView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("@\(post.authorUsername)")
                    .font(.headline)
                Spacer()
            }
            
            Text(post.content)
                .font(.body)
            
            HStack {
                Image(systemName: "heart")
                Text("\(post.likesCount)")
                
                Spacer()
                
                Image(systemName: "message")
                Text("\(post.commentsCount)")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    SocialFeedView()
        .environmentObject(FirebaseAuthService.shared)
}