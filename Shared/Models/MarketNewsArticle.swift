//
//  MarketNewsArticle.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//

// CREATE A NEW FILE: Shared/Models/MarketNewsArticle.swift
// MarketNewsArticle Model - MOVE THIS TO Shared/Models/ folder

import Foundation
import FirebaseFirestore

// MARK: - Market News Article Model
struct MarketNewsArticle: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String?  // Changed from summary to match Firebase service
    let content: String?
    let articleUrl: String?
    let imageUrl: String?
    let source: String?  // Made optional to match Firebase service
    let author: String?
    let publishedUtc: Date  // Changed from publishedAt to match Firebase service
    let category: NewsCategory
    let keywords: [String]  // Changed from tickerSymbols to match Firebase service
    let sentiment: NewsSentiment
    let isBreaking: Bool
    let viewCount: Int
    let shareCount: Int
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        content: String? = nil,
        articleUrl: String? = nil,
        imageUrl: String? = nil,
        source: String? = nil,
        author: String? = nil,
        publishedUtc: Date = Date(),
        category: NewsCategory = .general,
        keywords: [String] = [],
        sentiment: NewsSentiment = .neutral,
        isBreaking: Bool = false,
        viewCount: Int = 0,
        shareCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.articleUrl = articleUrl
        self.imageUrl = imageUrl
        self.source = source
        self.author = author
        self.publishedUtc = publishedUtc
        self.category = category
        self.keywords = keywords
        self.sentiment = sentiment
        self.isBreaking = isBreaking
        self.viewCount = viewCount
        self.shareCount = shareCount
    }
    
    static func == (lhs: MarketNewsArticle, rhs: MarketNewsArticle) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "title": title,
            "description": description as Any,
            "content": content as Any,
            "articleUrl": articleUrl as Any,
            "imageUrl": imageUrl as Any,
            "source": source as Any,
            "author": author as Any,
            "publishedUtc": Timestamp(date: publishedUtc),
            "category": category.rawValue,
            "keywords": keywords,
            "sentiment": sentiment.rawValue,
            "isBreaking": isBreaking,
            "viewCount": viewCount,
            "shareCount": shareCount,
            "cachedAt": Timestamp(date: Date())  // Added for Firebase service compatibility
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> MarketNewsArticle {
        guard let title = data["title"] as? String,
              let publishedUtcTimestamp = data["publishedUtc"] as? Timestamp,
              let categoryString = data["category"] as? String,
              let category = NewsCategory(rawValue: categoryString),
              let sentimentString = data["sentiment"] as? String,
              let sentiment = NewsSentiment(rawValue: sentimentString),
              let isBreaking = data["isBreaking"] as? Bool,
              let viewCount = data["viewCount"] as? Int,
              let shareCount = data["shareCount"] as? Int else {
            throw FirestoreError.invalidData
        }
        
        return MarketNewsArticle(
            id: id,
            title: title,
            description: data["description"] as? String,
            content: data["content"] as? String,
            articleUrl: data["articleUrl"] as? String,
            imageUrl: data["imageUrl"] as? String,
            source: data["source"] as? String,
            author: data["author"] as? String,
            publishedUtc: publishedUtcTimestamp.dateValue(),
            category: category,
            keywords: data["keywords"] as? [String] ?? [],
            sentiment: sentiment,
            isBreaking: isBreaking,
            viewCount: viewCount,
            shareCount: shareCount
        )
    }
}

// MARK: - News Category Enum
enum NewsCategory: String, CaseIterable, Codable {
    case general = "general"
    case markets = "markets"
    case stocks = "stocks"
    case crypto = "crypto"
    case forex = "forex"
    case earnings = "earnings"
    case economy = "economy"
    case politics = "politics"
    case technology = "technology"
    case breaking = "breaking"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .markets: return "Markets"
        case .stocks: return "Stocks"
        case .crypto: return "Crypto"
        case .forex: return "Forex"
        case .earnings: return "Earnings"
        case .economy: return "Economy"
        case .politics: return "Politics"
        case .technology: return "Technology"
        case .breaking: return "Breaking"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "newspaper"
        case .markets: return "chart.line.uptrend.xyaxis"
        case .stocks: return "building.columns"
        case .crypto: return "bitcoinsign.circle"
        case .forex: return "dollarsign.circle"
        case .earnings: return "chart.bar.doc.horizontal"
        case .economy: return "banknote"
        case .politics: return "building.columns"
        case .technology: return "laptopcomputer"
        case .breaking: return "exclamationmark.triangle"
        }
    }
    
    var color: String {
        switch self {
        case .general: return "blue"
        case .markets: return "green"
        case .stocks: return "purple"
        case .crypto: return "orange"
        case .forex: return "teal"
        case .earnings: return "indigo"
        case .economy: return "pink"
        case .politics: return "red"
        case .technology: return "cyan"
        case .breaking: return "red"
        }
    }
}

// MARK: - News Sentiment Enum
enum NewsSentiment: String, CaseIterable, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .positive: return "Positive"
        case .negative: return "Negative"
        case .neutral: return "Neutral"
        }
    }
    
    var color: String {
        switch self {
        case .positive: return "green"
        case .negative: return "red"
        case .neutral: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "arrow.up.circle"
        case .negative: return "arrow.down.circle"
        case .neutral: return "minus.circle"
        }
    }
}

// MARK: - News Analytics Model (matching Firebase service expectations)

