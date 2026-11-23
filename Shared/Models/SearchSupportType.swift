// File: Shared/Models/SearchSupportType.swift
// The Discover search scopes (All, Communities, Traders, Posts, Trades).

import Foundation
import SwiftUI

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
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .users: return .blue
        case .posts: return .purple
        case .stocks: return .green
        case .groups: return .orange
        }
    }
    
    var activeIcon: String {
        switch self {
        case .all: return "magnifyingglass.circle.fill"
        case .users: return "person.2.circle.fill"
        case .posts: return "text.bubble.fill"
        case .stocks: return "chart.line.uptrend.xyaxis.circle.fill"
        case .groups: return "person.3.fill"
        }
    }
}
