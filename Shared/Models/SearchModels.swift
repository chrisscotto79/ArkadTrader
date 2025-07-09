// File: Shared/Models/SearchModels.swift
// Fixed Search Models - proper handling of search results

import Foundation

struct SearchResult: Identifiable, Codable {
    let id: UUID
    let type: SearchResultType
    let user: User?
    let post: Post?
    
    init(user: User) {
        self.id = UUID()
        self.type = .user
        self.user = user
        self.post = nil
    }
    
    init(post: Post) {
        self.id = UUID()
        self.type = .post
        self.user = nil
        self.post = post
    }
}

enum SearchResultType: String, CaseIterable, Codable {
    case user = "user"
    case post = "post"
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .post: return "Post"
        }
    }
}
