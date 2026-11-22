// File: Shared/Models/SearchSupportTypes.swift
// Enhanced supporting types for advanced search functionality

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

// MARK: - Search Sort Options (defined in SearchViewModel.swift)
// SearchSortOption enum is defined in SearchViewModel.swift to avoid duplication

// MARK: - Enhanced Trending Topic
struct TrendingTopic: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let count: String
    let category: TrendingCategory
    let changePercentage: Double
    let isRising: Bool
    let hashtags: [String]
    let createdAt: Date
    
    init(title: String, subtitle: String, count: String, category: TrendingCategory = .general, changePercentage: Double = 0, hashtags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.category = category
        self.changePercentage = changePercentage
        self.isRising = changePercentage > 0
        self.hashtags = hashtags
        self.createdAt = Date()
    }
    
    var displayChangePercentage: String {
        let sign = changePercentage > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", changePercentage))%"
    }
    
    var trendIcon: String {
        return isRising ? "arrow.up.right" : "arrow.down.right"
    }
    
    var trendColor: Color {
        return isRising ? .green : .red
    }
}

// MARK: - Trending Categories
enum TrendingCategory: String, CaseIterable, Codable {
    case general = "general"
    case stocks = "stocks"
    case crypto = "crypto"
    case trading = "trading"
    case analysis = "analysis"
    case education = "education"
    case community = "community"
    case news = "news"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .stocks: return "Stocks"
        case .crypto: return "Crypto"
        case .trading: return "Trading"
        case .analysis: return "Analysis"
        case .education: return "Education"
        case .community: return "Community"
        case .news: return "News"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "star"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .crypto: return "bitcoinsign.circle"
        case .trading: return "arrow.up.arrow.down"
        case .analysis: return "chart.bar"
        case .education: return "graduationcap"
        case .community: return "person.3"
        case .news: return "newspaper"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .stocks: return .green
        case .crypto: return .orange
        case .trading: return .blue
        case .analysis: return .purple
        case .education: return .indigo
        case .community: return .pink
        case .news: return .red
        }
    }
}

// MARK: - Enhanced Search Suggestion
struct SearchSuggestion: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let type: SearchResultType
    let icon: String
    let category: String
    let isPopular: Bool
    let searchCount: Int
    let lastSearched: Date?
    
    init(text: String, type: SearchResultType, category: String = "general", isPopular: Bool = false, searchCount: Int = 0) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.icon = type.icon
        self.category = category
        self.isPopular = isPopular
        self.searchCount = searchCount
        self.lastSearched = nil
    }
    
    var displayText: String {
        return text
    }
    
    var popularityIndicator: String? {
        if isPopular {
            return "🔥"
        } else if searchCount > 100 {
            return "⭐"
        }
        return nil
    }
}

// MARK: - Date Range Filter
struct DateRange: Codable, Hashable {
    let startDate: Date
    let endDate: Date
    
    static var lastWeek: DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    static var lastMonth: DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    static var lastYear: DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

// MARK: - Price Range Filter
struct PriceRange: Codable, Hashable {
    let minPrice: Double
    let maxPrice: Double
    
    static var under10: PriceRange {
        return PriceRange(minPrice: 0, maxPrice: 10)
    }
    
    static var between10And100: PriceRange {
        return PriceRange(minPrice: 10, maxPrice: 100)
    }
    
    static var between100And1000: PriceRange {
        return PriceRange(minPrice: 100, maxPrice: 1000)
    }
    
    static var over1000: PriceRange {
        return PriceRange(minPrice: 1000, maxPrice: Double.infinity)
    }
    
    var displayName: String {
        if maxPrice == Double.infinity {
            return "$\(Int(minPrice))+"
        } else {
            return "$\(Int(minPrice)) - $\(Int(maxPrice))"
        }
    }
}

// MARK: - Search Analytics
struct SearchAnalytics: Codable {
    let totalSearches: Int
    let averageResultsPerSearch: Double
    let averageSearchTime: TimeInterval
    let popularQueries: [String]
    let searchSessionDuration: TimeInterval
    let cacheHitRate: Double
    
    static var empty: SearchAnalytics {
        return SearchAnalytics(
            totalSearches: 0,
            averageResultsPerSearch: 0,
            averageSearchTime: 0,
            popularQueries: [],
            searchSessionDuration: 0,
            cacheHitRate: 0
        )
    }
}
