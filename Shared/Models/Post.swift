// File: Shared/Models/Post.swift
// Enhanced Post Model with Trading Features & Media Support

import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    var id: String
    var content: String
    var authorId: String
    var authorUsername: String
    /// Stored when the post is created so feeds don't look up each author. Older posts don't have them.
    var authorFullName: String?
    var authorAvatarURL: String?
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

    /// Set on the server copy after repeated reports; hidden posts stay out of feeds
    var isHidden = false

    // Trade-result posts (docs/backend-contracts.md, section 0): the author's own closed trade and a
    // copy of its numbers and proof label, which the rules check against the trade document.
    // Both are fixed once posted.
    var tradeId: String?
    var tradeSnapshot: TradeSnapshot?

    /// Optional Bullish/Bearish tag ("bullish" / "bearish" in Firestore; missing means none)
    var sentiment: PostSentiment?

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
        
        if let authorFullName {
            data["authorFullName"] = authorFullName
        }
        if let authorAvatarURL, !authorAvatarURL.isEmpty {
            data["authorAvatarURL"] = authorAvatarURL
        }

        // Add trading data if exists (older trade posts; new ones use tradeSnapshot)
        if let tradingData = tradingData {
            data["tradingData"] = tradingData.toFirestore()
        }

        // FirebaseServices.createPost replaces the snapshot with one copied from the trade document
        if let tradeId, let tradeSnapshot {
            data["tradeId"] = tradeId
            data["tradeSnapshot"] = tradeSnapshot.toFirestore()
        }

        if let sentiment {
            data[PostSentiment.firestoreField] = sentiment.rawValue
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
        post.authorFullName = (data["authorFullName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        post.authorAvatarURL = (data["authorAvatarURL"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        post.isHidden = data["isHidden"] as? Bool ?? false
        
        // Load trading data if exists
        if let tradingDataDict = data["tradingData"] as? [String: Any] {
            post.tradingData = TradingData.fromFirestore(tradingDataDict)
        }
        post.tradeId = data["tradeId"] as? String
        post.tradeSnapshot = (data["tradeSnapshot"] as? [String: Any]).flatMap(TradeSnapshot.fromFirestore)
        post.sentiment = PostSentiment(firestoreValue: data[PostSentiment.firestoreField])

        return post
    }
}

// MARK: - Trade snapshot

/// `tradeSnapshot` on a trade-result post: copied from the author's closed trade when posting.
/// The card shows these numbers (P&L computed from them) and the proof label; nothing is typed in.
struct TradeSnapshot: Codable, Equatable {
    var ticker: String
    /// `TradeType` raw value ("stock", "option", "crypto", "forex")
    var tradeType: String
    var entryPrice: Double
    var exitPrice: Double
    var quantity: Double
    var entryDate: Date
    var exitDate: Date
    var proof: TradeProof

    var assetType: TradeType? { TradeType(rawValue: tradeType) }
    var profitLoss: Double { (exitPrice - entryPrice) * quantity }
    var profitLossPercentage: Double { entryPrice > 0 ? (exitPrice - entryPrice) / entryPrice * 100 : 0 }

    /// From a closed trade. Nil while the trade is open.
    init?(trade: Trade) {
        guard !trade.isOpen, let exitPrice = trade.exitPrice else { return nil }
        self.ticker = trade.ticker
        self.tradeType = trade.tradeType.rawValue
        self.entryPrice = trade.entryPrice
        self.exitPrice = exitPrice
        self.quantity = trade.quantity
        self.entryDate = trade.entryDate
        self.exitDate = trade.exitDate ?? trade.entryDate
        self.proof = trade.proof
    }

    init(ticker: String, tradeType: String, entryPrice: Double, exitPrice: Double, quantity: Double,
         entryDate: Date, exitDate: Date, proof: TradeProof) {
        self.ticker = ticker
        self.tradeType = tradeType
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.quantity = quantity
        self.entryDate = entryDate
        self.exitDate = exitDate
        self.proof = proof
    }

    func toFirestore() -> [String: Any] {
        [
            "ticker": ticker,
            "tradeType": tradeType,
            "entryPrice": entryPrice,
            "exitPrice": exitPrice,
            "quantity": quantity,
            "entryDate": Timestamp(date: entryDate),
            "exitDate": Timestamp(date: exitDate),
            "proof": proof.rawValue
        ]
    }

    /// The snapshot exactly as the rules compare it, built from the raw trade document: same
    /// value types as stored (numbers, Timestamps), and `proof` defaulting to "self_reported".
    /// Nil unless the trade is closed and has an exit price.
    static func firestoreData(fromTradeDocument trade: [String: Any]) -> [String: Any]? {
        guard trade["isOpen"] as? Bool == false,
              let ticker = trade["ticker"] as? String,
              let tradeType = trade["tradeType"] as? String,
              let entryPrice = trade["entryPrice"] as? NSNumber,
              let exitPrice = trade["exitPrice"] as? NSNumber,
              let quantity = trade["quantity"] as? NSNumber,
              let entryDate = trade["entryDate"] as? Timestamp else { return nil }
        return [
            "ticker": ticker,
            "tradeType": tradeType,
            "entryPrice": entryPrice,
            "exitPrice": exitPrice,
            "quantity": quantity,
            "entryDate": entryDate,
            "exitDate": (trade["exitDate"] as? Timestamp) ?? entryDate,
            "proof": (trade["proof"] as? String) ?? TradeProof.selfReported.rawValue
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> TradeSnapshot? {
        guard let ticker = data["ticker"] as? String,
              let entryPrice = (data["entryPrice"] as? NSNumber)?.doubleValue,
              let exitPrice = (data["exitPrice"] as? NSNumber)?.doubleValue,
              let quantity = (data["quantity"] as? NSNumber)?.doubleValue else { return nil }
        let entryDate = (data["entryDate"] as? Timestamp)?.dateValue() ?? Date.distantPast
        return TradeSnapshot(
            ticker: ticker,
            tradeType: data["tradeType"] as? String ?? TradeType.stock.rawValue,
            entryPrice: entryPrice,
            exitPrice: exitPrice,
            quantity: quantity,
            entryDate: entryDate,
            exitDate: (data["exitDate"] as? Timestamp)?.dateValue() ?? entryDate,
            proof: TradeProof(firestoreValue: data["proof"])
        )
    }
}

// ✅ Trading Data Structure (older trade posts with typed-in numbers; shown as self-reported)
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
        guard let value = profitLossValue else { return profitLossString ?? "" }
        let formatted = abs(value).formatted(.currency(code: "USD"))
        return (value < 0 ? "-" : "+") + formatted
    }

    var isProfitable: Bool {
        (profitLossValue ?? 0) >= 0
    }
    
    var profitLossEmoji: String {
        return isProfitable ? "💰" : "📉"
    }

    /// The P&L as a number, from the stored value or the stored text ("+$1,200", "-$50")
    var profitLossValue: Double? {
        if let profitLoss { return profitLoss }
        guard let text = profitLossString else { return nil }
        return TradingData.parseAmount(text)
    }

    /// "$12.50", "+$1,200", "-50" -> number. Nil when there's no digit to read.
    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text.filter { "0123456789.-".contains($0) }
        guard cleaned.contains(where: \.isNumber) else { return nil }
        return Double(cleaned)
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

    /// Post text for display. Older trade posts were written from a template with "$[Entry]"-style
    /// placeholders that people typed inside, leaving "$[200]"; this drops those brackets.
    var displayContent: String {
        guard content.contains("[") else { return content }
        let unbracketed = content.replacingOccurrences(
            of: #"\[([^\[\]\n]{1,60})\]"#, with: "$1", options: .regularExpression)
        // "$aapl" -> "$AAPL"
        let ns = unbracketed as NSString
        var result = unbracketed
        let regex = try! NSRegularExpression(pattern: #"\$([a-z]{1,5})\b"#)
        for match in regex.matches(in: unbracketed, range: NSRange(location: 0, length: ns.length)).reversed() {
            let ticker = ns.substring(with: match.range(at: 1)).uppercased()
            result = (result as NSString).replacingCharacters(in: match.range, with: "$" + ticker)
        }
        return result
    }

    /// The proof label of a trade-result post: the snapshot's, or self-reported for older posts
    /// whose numbers were typed in.
    var tradeProof: TradeProof {
        tradeSnapshot?.proof ?? .selfReported
    }

    /// Trade numbers to show on the card. New trade posts use the snapshot of the author's closed
    /// trade. Older posts: nil unless there's an actual P&L, so a trade post without numbers doesn't
    /// show a "$0.00" card; falls back to the "P&L:" line in the text.
    var tradeSummary: TradingData? {
        if let tradeSnapshot {
            var data = TradingData()
            data.ticker = tradeSnapshot.ticker
            data.entryPrice = tradeSnapshot.entryPrice
            data.exitPrice = tradeSnapshot.exitPrice
            data.profitLoss = tradeSnapshot.profitLoss
            let terms = AssetTerms(tradeSnapshot.assetType ?? .stock)
            data.positionSize = terms.quantityText(tradeSnapshot.quantity, symbol: tradeSnapshot.ticker)
            return data
        }
        if let tradingData, tradingData.profitLossValue != nil { return tradingData }
        guard postType == .tradeResult,
              let range = displayContent.range(of: #"P&L:\s*[+-]?\$?-?[0-9][0-9,]*(\.[0-9]+)?"#, options: .regularExpression),
              let amount = TradingData.parseAmount(String(displayContent[range].dropFirst(4)))
        else { return nil }
        var summary = tradingData ?? TradingData()
        summary.profitLoss = displayContent[range].contains("-") ? -abs(amount) : amount
        summary.profitLossString = nil
        return summary
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

