// File: Shared/Models/SearchModels.swift
// Updated Search Models with full support for all types

import Foundation
import SwiftUI

struct SearchResult: Identifiable, Codable {
    let id: UUID
    let type: SearchResultType
    let user: User?
    let post: Post?
    let trade: Trade?
    let community: Community?
    
    init(user: User) {
        self.id = UUID()
        self.type = .user
        self.user = user
        self.post = nil
        self.trade = nil
        self.community = nil
    }
    
    init(post: Post) {
        self.id = UUID()
        self.type = .post
        self.user = nil
        self.post = post
        self.trade = nil
        self.community = nil
    }
    
    init(trade: Trade) {
        self.id = UUID()
        self.type = .trade
        self.user = nil
        self.post = nil
        self.trade = trade
        self.community = nil
    }
    
    init(community: Community) {
        self.id = UUID()
        self.type = .group
        self.user = nil
        self.post = nil
        self.trade = nil
        self.community = community
    }
}

enum SearchResultType: String, CaseIterable, Codable {
    case user = "user"
    case post = "post"
    case trade = "trade"
    case group = "group"
    
    var displayName: String {
        switch self {
        case .user: return "User"
        case .post: return "Post"
        case .trade: return "Trade"
        case .group: return "Group"
        }
    }
    
    var icon: String {
        switch self {
        case .user: return "person.circle.fill"
        case .post: return "text.bubble.fill"
        case .trade: return "chart.line.uptrend.xyaxis"
        case .group: return "person.3.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .user: return .blue
        case .post: return .purple
        case .trade: return .green
        case .group: return .orange
        }
    }
}
