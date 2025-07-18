// File: Shared/Models/Post.swift
// Enhanced Post Model with Trading Features & Media Support

import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    var id: String
    var content: String
    var authorId: String
    var authorUsername: String
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var postType: PostType
    
    // ✅ New trading-specific fields
    var tickers: [String] = []
    var tradingData: TradingData?
    
    // ✅ New media fields
    var imageUrls: [String] = []
    var hasMedia: Bool { !imageUrls.isEmpty }
    
    // ✅ Enhanced content analysis
    var hashtags: [String] = []
    var mentions: [String] = []

    // Basic initializer
    init(content: String, authorId: String, authorUsername: String) {
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.postType = .text
        
        // Auto-extract tickers and hashtags
        self.tickers = extractTickers(from: content)
        self.hashtags = extractHashtags(from: content)
        self.mentions = extractMentions(from: content)
    }
    
    // Enhanced initializer with trading data
    init(content: String,
         authorId: String,
         authorUsername: String,
         postType: PostType,
         tickers: [String] = [],
         tradingData: TradingData? = nil,
         imageUrls: [String] = []) {
        
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.postType = postType
        self.tickers = tickers
        self.tradingData = tradingData
        self.imageUrls = imageUrls
        
        // Auto-extract content features
        self.hashtags = extractHashtags(from: content)
        self.mentions = extractMentions(from: content)
    }

    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": Timestamp(date: createdAt),
            "postType": postType.rawValue,
            "tickers": tickers,
            "imageUrls": imageUrls,
            "hashtags": hashtags,
            "mentions": mentions
        ]
        
        // Add trading data if exists
        if let tradingData = tradingData {
            data["tradingData"] = tradingData.toFirestore()
        }
        
        return data
    }

    static func fromFirestore(data: [String: Any], id: String) throws -> Post {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let likesCount = data["likesCount"] as? Int,
              let commentsCount = data["commentsCount"] as? Int,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let postTypeString = data["postType"] as? String,
              let postType = PostType(rawValue: postTypeString) else {
            throw NSError(domain: "PostDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid post data"])
        }

        var post = Post(content: content, authorId: authorId, authorUsername: authorUsername)
        post.id = id
        post.likesCount = likesCount
        post.commentsCount = commentsCount
        post.createdAt = createdAtTimestamp.dateValue()
        post.postType = postType
        
        // ✅ Load enhanced fields
        post.tickers = data["tickers"] as? [String] ?? []
        post.imageUrls = data["imageUrls"] as? [String] ?? []
        post.hashtags = data["hashtags"] as? [String] ?? []
        post.mentions = data["mentions"] as? [String] ?? []
        
        // Load trading data if exists
        if let tradingDataDict = data["tradingData"] as? [String: Any] {
            post.tradingData = TradingData.fromFirestore(tradingDataDict)
        }

        return post
    }
}

// ✅ Trading Data Structure
struct TradingData: Codable {
    var profitLoss: Double?
    var profitLossString: String?
    var positionSize: String?
    var entryPrice: Double?
    var exitPrice: Double?
    var entryPriceString: String?
    var exitPriceString: String?
    var ticker: String?
    var tradeType: TradeType?
    
    enum TradeType: String, Codable, CaseIterable {
        case long = "long"
        case short = "short"
        case options = "options"
        case crypto = "crypto"
        
        var displayName: String {
            switch self {
            case .long: return "Long"
            case .short: return "Short"
            case .options: return "Options"
            case .crypto: return "Crypto"
            }
        }
        
        var emoji: String {
            switch self {
            case .long: return "📈"
            case .short: return "📉"
            case .options: return "⚡"
            case .crypto: return "₿"
            }
        }
    }
    
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [:]
        
        if let profitLoss = profitLoss {
            data["profitLoss"] = profitLoss
        }
        if let profitLossString = profitLossString {
            data["profitLossString"] = profitLossString
        }
        if let positionSize = positionSize {
            data["positionSize"] = positionSize
        }
        if let entryPrice = entryPrice {
            data["entryPrice"] = entryPrice
        }
        if let exitPrice = exitPrice {
            data["exitPrice"] = exitPrice
        }
        if let entryPriceString = entryPriceString {
            data["entryPriceString"] = entryPriceString
        }
        if let exitPriceString = exitPriceString {
            data["exitPriceString"] = exitPriceString
        }
        if let ticker = ticker {
            data["ticker"] = ticker
        }
        if let tradeType = tradeType {
            data["tradeType"] = tradeType.rawValue
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> TradingData {
        var tradingData = TradingData()
        
        tradingData.profitLoss = data["profitLoss"] as? Double
        tradingData.profitLossString = data["profitLossString"] as? String
        tradingData.positionSize = data["positionSize"] as? String
        tradingData.entryPrice = data["entryPrice"] as? Double
        tradingData.exitPrice = data["exitPrice"] as? Double
        tradingData.entryPriceString = data["entryPriceString"] as? String
        tradingData.exitPriceString = data["exitPriceString"] as? String
        tradingData.ticker = data["ticker"] as? String
        
        if let tradeTypeString = data["tradeType"] as? String {
            tradingData.tradeType = TradeType(rawValue: tradeTypeString)
        }
        
        return tradingData
    }
    
    // ✅ Computed properties for display
    var formattedProfitLoss: String {
        if let profitLossString = profitLossString, !profitLossString.isEmpty {
            return profitLossString
        }
        
        if let profitLoss = profitLoss {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            return formatter.string(from: NSNumber(value: profitLoss)) ?? "$0.00"
        }
        
        return "$0.00"
    }
    
    var isProfitable: Bool {
        if let profitLoss = profitLoss {
            return profitLoss > 0
        }
        
        if let profitLossString = profitLossString {
            // Try to parse profit/loss from string
            let cleanString = profitLossString.replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            
            if let value = Double(cleanString) {
                return value > 0
            }
        }
        
        return false
    }
    
    var profitLossEmoji: String {
        return isProfitable ? "💰" : "📉"
    }
}

enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case tradeResult = "trade_result"
    case marketAnalysis = "market_analysis"

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .tradeResult: return "Trade Result"
        case .marketAnalysis: return "Market Analysis"
        }
    }
    
    var emoji: String {
        switch self {
        case .text: return "💬"
        case .tradeResult: return "📊"
        case .marketAnalysis: return "🔍"
        }
    }
    
    var color: Color {
        switch self {
        case .text: return .blue
        case .tradeResult: return .green
        case .marketAnalysis: return .purple
        }
    }
}

// MARK: - Content Extraction Functions

func extractTickers(from content: String) -> [String] {
    let pattern = "\\$[A-Z]{1,5}\\b"
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
    
    let tickers = matches.compactMap { match in
        String(content[Range(match.range, in: content)!]).replacingOccurrences(of: "$", with: "")
    }
    
    return Array(Set(tickers)) // Remove duplicates
}

func extractHashtags(from content: String) -> [String] {
    let pattern = "#[A-Za-z0-9_]+"
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
    
    let hashtags = matches.compactMap { match in
        String(content[Range(match.range, in: content)!])
    }
    
    return Array(Set(hashtags)) // Remove duplicates
}

func extractMentions(from content: String) -> [String] {
    let pattern = "@[A-Za-z0-9_]+"
    let regex = try! NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
    
    let mentions = matches.compactMap { match in
        String(content[Range(match.range, in: content)!]).replacingOccurrences(of: "@", with: "")
    }
    
    return Array(Set(mentions)) // Remove duplicates
}

// MARK: - Post Extensions for Display

extension Post {
    var displayTickers: String {
        return tickers.map { "$\($0)" }.joined(separator: " ")
    }
    
    var displayHashtags: String {
        return hashtags.joined(separator: " ")
    }
    
    var hasTradingData: Bool {
        return tradingData != nil
    }
    
    var formattedContent: String {
        var formatted = content
        
        // Highlight tickers
        for ticker in tickers {
            formatted = formatted.replacingOccurrences(
                of: "$\(ticker)",
                with: "💰$\(ticker)"
            )
        }
        
        return formatted
    }
    
    // ✅ Search functionality
    func matches(query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        
        return content.lowercased().contains(lowercaseQuery) ||
               authorUsername.lowercased().contains(lowercaseQuery) ||
               tickers.contains { $0.lowercased().contains(lowercaseQuery) } ||
               hashtags.contains { $0.lowercased().contains(lowercaseQuery) }
    }
}

import SwiftUI

