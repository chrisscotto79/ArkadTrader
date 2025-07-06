// File: Core/Home/ViewModels/HomeViewModel.swift

import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false

    private let authService = FirebaseAuthService.shared

    func loadPosts() async {
        isLoading = true
        do {
            posts = try await authService.getFeedPosts()
        } catch {
            print("Error loading posts: \(error)")
        }
        isLoading = false
    }

    func createPost(content: String) async {
        guard let userId = authService.currentUser?.id,
              let username = authService.currentUser?.username else { return }

        let newPost = Post(content: content, authorId: userId, authorUsername: username)

        do {
            try await authService.createPost(newPost)
            await loadPosts()
        } catch {
            print("Error creating post: \(error)")
        }
    }
}
