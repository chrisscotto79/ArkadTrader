// File: Shared/Models/Post.swift
// Enhanced Post Model with Trading Features & Media Support

import Foundation
import FirebaseFirestore
import SwiftUI

struct Post: Identifiable, Codable {
    /// Limits the database rules enforce on new posts.
    static let maxContentLength = 2000
    static let maxTickers = 10
    static let maxHashtags = 10

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
    
    // Trading fields
    var tickers: [String] = []
    var tradingData: TradingData?
    
    // Media
    var imageUrls: [String] = []
    
    // Content analysis
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
        self.tickers = Cashtag.cleaned(tickers)
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
            "tickers": Cashtag.cleaned(tickers),
            "imageUrls": imageUrls,
            "hashtags": Array(hashtags.prefix(Post.maxHashtags)),
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

    /// A post from a query result. Reads pending server timestamps (your own post that hasn't
    /// reached the server yet) as their estimated value.
    static func fromDocument(_ document: DocumentSnapshot) -> Post? {
        guard let data = document.data(with: .estimate) else { return nil }
        return try? fromFirestore(data: data, id: document.documentID)
    }

    static func fromFirestore(data: [String: Any], id: String) throws -> Post {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let postTypeString = data["postType"] as? String,
              let postType = PostType(rawValue: postTypeString) else {
            throw NSError(domain: "PostDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid post data"])
        }

        var post = Post(content: content, authorId: authorId, authorUsername: authorUsername)
        post.id = id
        post.likesCount = max(0, data["likesCount"] as? Int ?? 0)
        post.commentsCount = max(0, data["commentsCount"] as? Int ?? 0)
        // A pending server timestamp reads as nil (or NSNull) without `.estimate`
        post.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        post.postType = postType

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
    /// "long" or "short" (older snapshots have none: long).
    var side: String = "long"

    var assetType: TradeType? { TradeType(rawValue: tradeType) }
    private var sign: Double { side == "short" ? -1 : 1 }
    var profitLoss: Double { sign * (exitPrice - entryPrice) * quantity }
    var profitLossPercentage: Double { entryPrice > 0 ? sign * (exitPrice - entryPrice) / entryPrice * 100 : 0 }

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
        self.side = trade.side.rawValue
    }

    init(ticker: String, tradeType: String, entryPrice: Double, exitPrice: Double, quantity: Double,
         entryDate: Date, exitDate: Date, proof: TradeProof, side: String = "long") {
        self.ticker = ticker
        self.tradeType = tradeType
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.quantity = quantity
        self.entryDate = entryDate
        self.exitDate = exitDate
        self.proof = proof
        self.side = side
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
            "proof": proof.rawValue,
            "side": side
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
            "proof": (trade["proof"] as? String) ?? TradeProof.selfReported.rawValue,
            "side": (trade["side"] as? String) ?? "long"
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
            proof: TradeProof(firestoreValue: data["proof"]),
            side: data["side"] as? String ?? "long"
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

// MARK: - Cashtags, hashtags and mentions

/// "$AAPL"-style cashtags. Matching ignores case ("$nvda" is NVDA) and allows a share-class
/// suffix ("$BRK.B"). Symbols are stored uppercased: 1-5 letters plus an optional ".X", the
/// same pattern the database rules check for `tickers`.
enum Cashtag {
    /// A "$" not inside another word, 1-5 letters, an optional ".X" class, then a word end.
    private static let regex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9_$])\$([A-Za-z]{1,5}(?:\.[A-Za-z])?)(?![A-Za-z0-9_])"#)

    private static let symbolRegex = try! NSRegularExpression(pattern: #"^[A-Z]{1,5}(\.[A-Z])?$"#)

    /// "$aapl " -> "AAPL"
    static func normalize(_ ticker: String) -> String {
        var symbol = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        while symbol.hasPrefix("$") { symbol.removeFirst() }
        return symbol
    }

    /// True for an uppercased symbol like "AAPL" or "BRK.B".
    static func isValid(_ symbol: String) -> Bool {
        let range = NSRange(symbol.startIndex..., in: symbol)
        return symbolRegex.firstMatch(in: symbol, range: range) != nil
    }

    /// Every cashtag in `text` with its range, in order (duplicates included).
    static func matches(in text: String) -> [(symbol: String, range: NSRange)] {
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (ns.substring(with: match.range(at: 1)).uppercased(), match.range)
        }
    }

    /// The symbols in `text`, uppercased, in the order they first appear, without duplicates.
    static func symbols(in text: String) -> [String] {
        var seen = Set<String>()
        return matches(in: text).map(\.symbol).filter { seen.insert($0).inserted }
    }

    /// `text` with every "$symbol" token (any case) removed, along with one space before it.
    /// "$A" inside "$AAPL" is left alone.
    static func removing(_ symbol: String, from text: String) -> String {
        let target = normalize(symbol)
        var result = text as NSString
        for match in matches(in: text).reversed() where match.symbol == target {
            var range = match.range
            if range.location > 0, result.substring(with: NSRange(location: range.location - 1, length: 1)) == " " {
                range = NSRange(location: range.location - 1, length: range.length + 1)
            }
            result = result.replacingCharacters(in: range, with: "") as NSString
        }
        return result as String
    }

    /// `text` with every cashtag uppercased: "$nvda" -> "$NVDA".
    static func uppercasingSymbols(in text: String) -> String {
        var result = text as NSString
        for match in matches(in: text).reversed() {
            result = result.replacingCharacters(in: match.range, with: "$" + match.symbol) as NSString
        }
        return result as String
    }

    /// Up to `limit` valid, uppercased, unique symbols, keeping their order.
    static func cleaned(_ tickers: [String], limit: Int = Post.maxTickers) -> [String] {
        var seen = Set<String>()
        return Array(tickers.map(normalize).filter { isValid($0) && seen.insert($0).inserted }.prefix(limit))
    }
}

/// Cashtag symbols in `content`, uppercased, in order of first appearance (at most 10).
func extractTickers(from content: String) -> [String] {
    Array(Cashtag.symbols(in: content).prefix(Post.maxTickers))
}

/// "#Tags" in `content`, in order of first appearance, without case-insensitive duplicates
/// (at most 10).
func extractHashtags(from content: String) -> [String] {
    uniqueTokens(in: content, pattern: "#[A-Za-z0-9_]+", keepPrefix: true, limit: Post.maxHashtags)
}

/// "@usernames" in `content` (without the "@"), in order, without duplicates.
func extractMentions(from content: String) -> [String] {
    // Not after a letter, digit, "_" or ".", so "bob@gmail.com" isn't a mention of "gmail".
    uniqueTokens(in: content, pattern: "(?<![A-Za-z0-9_.])@[A-Za-z0-9_]+", keepPrefix: false, limit: 20)
}

private func uniqueTokens(in content: String, pattern: String, keepPrefix: Bool, limit: Int) -> [String] {
    let regex = try! NSRegularExpression(pattern: pattern)
    let ns = content as NSString
    var seen = Set<String>()
    var tokens: [String] = []
    for match in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
        let token = ns.substring(with: match.range)
        let value = keepPrefix ? token : String(token.dropFirst())
        if seen.insert(value.lowercased()).inserted {
            tokens.append(value)
            if tokens.count == limit { break }
        }
    }
    return tokens
}

// MARK: - Post Extensions for Display

extension Post {
    /// Post text for display, with cashtags uppercased ("$nvda" -> "$NVDA") to match the ticker
    /// chips. Older trade posts were written from a template with "$[Entry]"-style placeholders
    /// that people typed inside, leaving "$[200]"; this drops those brackets.
    var displayContent: String {
        var text = content
        if text.contains("[") {
            text = text.replacingOccurrences(
                of: #"\[([^\[\]\n]{1,60})\]"#, with: "$1", options: .regularExpression)
        }
        return text.contains("$") ? Cashtag.uppercasingSymbols(in: text) : text
    }

    /// The post's tickers that are real cashtag symbols (older posts may hold others), for the
    /// tappable chips.
    var linkableTickers: [String] {
        Cashtag.cleaned(tickers)
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
}
