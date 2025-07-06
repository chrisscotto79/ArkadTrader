// File: Core/Home/ViewModels/HomeViewModel.swift
// Updated HomeViewModel for Firebase

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let authService = FirebaseAuthService.shared
    private let firestoreService = FirestoreService.shared
    
    init() {
        loadPosts()
    }
    
    func loadPosts() {
        isLoading = true
        
        Task {
            do {
                let posts = try await firestoreService.getFeedPosts()
                await MainActor.run {
                    self.posts = posts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.posts = createMockPosts() // Fallback to mock data
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshPosts() {
        loadPosts()
    }
    
    func likePost(_ post: Post) {
        // TODO: Implement like functionality with Firestore
        print("Liked post: \(post.id)")
    }
    
    func addComment(to post: Post, comment: String) {
        // TODO: Implement comment functionality with Firestore
        print("Added comment to post: \(post.id)")
    }
    
    func createPost(content: String, type: PostType = .text) {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }
        
        let newPost = Post(content: content, authorId: userId, authorUsername: username)
        
        Task {
            do {
                try await firestoreService.createPost(newPost)
                await MainActor.run {
                    self.posts.insert(newPost, at: 0)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create post: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func createMockPosts() -> [Post] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        return [
            Post(content: "Market looking bullish today! 📈 SPY hitting new highs", authorId: UUID().uuidString, authorUsername: "trader123"),
            Post(content: "Just closed my AAPL position with a +15% gain! 🚀", authorId: userId, authorUsername: authService.currentUser?.username ?? "user"),
            Post(content: "Anyone else watching TSLA today? Thinking about entering a position 🤔", authorId: UUID().uuidString, authorUsername: "marketwatcher"),
            Post(content: "NVDA earnings coming up next week. What's everyone's thoughts?", authorId: UUID().uuidString, authorUsername: "techanalyst")
        ]
    }
}
