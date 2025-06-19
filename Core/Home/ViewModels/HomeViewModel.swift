//
//  HomeViewModel.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Home/ViewModels/HomeViewModel.swift

import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    
    private let dataService = DataService.shared
    
    init() {
        loadPosts()
    }
    
    func loadPosts() {
        isLoading = true
        
        // For MVP, use mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.posts = self.dataService.posts
            self.isLoading = false
        }
    }
    
    func refreshPosts() {
        loadPosts()
    }
    
    func likePost(_ post: Post) {
        // TODO: Implement like functionality
        print("Liked post: \(post.id)")
    }
    
    func addComment(to post: Post, comment: String) {
        // TODO: Implement comment functionality
        print("Added comment to post: \(post.id)")
    }
}
