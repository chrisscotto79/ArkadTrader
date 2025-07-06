// File: Shared/Models/SearchModels.swift
// Simplified Search Models

import Foundation

struct SearchResult: Identifiable, Codable {
    let id: UUID
    let type: SearchResultType
    let user: User?
    
    init(user: User) {
        self.id = UUID()
        self.type = .user
        self.user = user
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
