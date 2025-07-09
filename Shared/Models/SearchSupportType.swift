// File: Shared/Models/SearchSupportTypes.swift
// Supporting types for search functionality

import Foundation

// MARK: - Search Type Filter
enum SearchType: String, CaseIterable {
    case all = "all"
    case users = "users"
    case posts = "posts"
    case stocks = "stocks"
    case groups = "groups"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .users: return "Users"
        case .posts: return "Posts"
        case .stocks: return "Stocks"
        case .groups: return "Groups"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "magnifyingglass"
        case .users: return "person.2"
        case .posts: return "text.bubble"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .groups: return "person.3"
        }
    }
}

// MARK: - Search Filters
enum SearchFilter: String, CaseIterable {
    case recent = "recent"
    case popular = "popular"
    case verified = "verified"
    case trending = "trending"
    
    var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .popular: return "Popular"
        case .verified: return "Verified"
        case .trending: return "Trending"
        }
    }
}

// MARK: - Trending Topic
struct TrendingTopic: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let count: String
    let category: String
    
    init(title: String, subtitle: String, count: String, category: String = "general") {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.category = category
    }
}

// MARK: - Search Suggestion
struct SearchSuggestion: Identifiable {
    let id: UUID
    let text: String
    let type: SearchResultType
    let icon: String
    
    init(text: String, type: SearchResultType) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.icon = type.icon
    }
}
