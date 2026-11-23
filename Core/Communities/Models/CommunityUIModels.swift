//
//  CommunityUIModels.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/19/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// FirestoreError is already defined elsewhere in the project

// MARK: - Channel Model
struct Channel: Identifiable, Codable {
    var id: String
    var name: String
    var type: ChannelType
    var communityId: String
    var isDefault: Bool // #general and #callouts are default channels
    var adminOnly: Bool // For #callouts channel
    var createdAt: Date
    /// Optional SF Symbol name stored as `icon`. The Announcements preset sets "megaphone.fill";
    /// nil means the type's own icon.
    var icon: String? = nil

    /// Icon used by the Announcements preset (an admin-only text channel).
    static let announcementsIcon = "megaphone.fill"

    /// An admin-only text channel created from the Announcements preset.
    var isAnnouncements: Bool { type != .callouts && adminOnly && icon == Channel.announcementsIcon }

    /// The icon to draw for this channel: its own, else the type's.
    var displayIcon: String {
        if let icon, !icon.isEmpty { return icon }
        return type == .callouts ? "megaphone.fill" : "number"
    }

    /// Callouts are gold, announcements blue, everything else neutral.
    var displayTint: Color {
        if type == .callouts { return .goldText }
        if isAnnouncements { return .info }
        return .secondary
    }
    
    init(name: String, type: ChannelType, communityId: String, isDefault: Bool = false, adminOnly: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.communityId = communityId
        self.isDefault = isDefault
        self.adminOnly = adminOnly
        self.createdAt = Date()
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "type": type.rawValue,
            "communityId": communityId,
            "isDefault": isDefault,
            "adminOnly": adminOnly,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let icon, !icon.isEmpty { data["icon"] = icon }
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Channel {
        guard let name = data["name"] as? String,
              let typeString = data["type"] as? String,
              let type = ChannelType(rawValue: typeString),
              let communityId = data["communityId"] as? String,
              let isDefault = data["isDefault"] as? Bool,
              let adminOnly = data["adminOnly"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var channel = Channel(name: name, type: type, communityId: communityId, isDefault: isDefault, adminOnly: adminOnly)
        channel.id = id
        channel.createdAt = createdAtTimestamp.dateValue()
        channel.icon = (data["icon"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return channel
    }
}

// MARK: - Channel Type Enum
enum ChannelType: String, CaseIterable, Codable {
    case text = "text"
    case callouts = "callouts"
    /// Legacy value kept so old channel documents still decode. There is no voice feature,
    /// so voice channels look and behave exactly like text channels.
    case voice = "voice"
    
    /// Types that can be picked when creating or editing a channel
    static let selectableTypes: [ChannelType] = [.text, .callouts]
    
    var displayName: String {
        switch self {
        case .text, .voice: return "Text"
        case .callouts: return "Callouts"
        }
    }
    
    var icon: String {
        switch self {
        case .text, .voice: return "number"
        case .callouts: return "megaphone"
        }
    }
}

// MARK: - CommunityMessage Model
struct CommunityMessage: Identifiable, Codable {
    var id: String
    var content: String
    var authorId: String
    var authorUsername: String
    /// Author's photo when the message was sent (newer messages only)
    var authorAvatarURL: String?
    var channelId: String
    var communityId: String
    var createdAt: Date
    /// Structured trade callout, when this message is one
    var callout: TradeCallout?

    // Trade posting kinds (docs/backend-contracts.md, section 11). A message carries at most one
    // of callout, calloutUpdate, calloutResult, tradeShare or gamePlan; `content` is always a
    // plain-text summary so older app versions still show something.
    /// The message this one replies to
    var replyTo: MessageReplyRef?
    /// The author's follow-up on their own open callout (trim, add, move stop / target, note)
    var calloutUpdate: CalloutUpdate?
    /// The author's result post after one of their callouts closed
    var calloutResult: CalloutResult?
    /// One of the author's logged trades, copied from `trades/{tradeId}`
    var tradeShare: TradeShareInfo?
    /// A leader's daily watchlist
    var gamePlan: GamePlan?

    /// True for callouts, updates, results, trade shares and game plans. Their `content` is a
    /// generated summary, so they aren't edited as text.
    var hasStructuredKind: Bool {
        callout != nil || calloutUpdate != nil || calloutResult != nil || tradeShare != nil || gamePlan != nil
    }

    /// One line describing the message, for reply quotes, banners, pins and search.
    var previewText: String {
        if isDeleted { return "Message deleted" }
        if let callout { return "\(callout.direction.displayName) $\(callout.ticker) callout" }
        if let gamePlan { return gamePlan.title }
        if content.hasPrefix("[MEDIA:IMAGE]") { return "Photo" }
        if content.hasPrefix("[MEDIA:VIDEO]") { return "Video" }
        if content.hasPrefix("[MEDIA:DOCUMENT]") {
            let parts = String(content.dropFirst(16)).components(separatedBy: "|")
            return parts.count >= 2 ? parts[1] : "Document"
        }
        return content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Editing and moderation (docs/backend-contracts.md, section 1)
    var editedAt: Date?
    /// Soft delete: the content is cleared and the row shows "Message deleted"
    var isDeleted: Bool = false
    var deletedBy: String?
    var deletedAt: Date?
    var isPinned: Bool = false
    var pinnedBy: String?
    var pinnedAt: Date?

    var isEdited: Bool { editedAt != nil }

    init(content: String, authorId: String, authorUsername: String, channelId: String, communityId: String, authorAvatarURL: String? = nil) {
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorAvatarURL = authorAvatarURL
        self.channelId = channelId
        self.communityId = communityId
        self.createdAt = Date()
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "channelId": channelId,
            "communityId": communityId,
            "createdAt": Timestamp(date: createdAt),
            "isDeleted": isDeleted,
            "isPinned": isPinned
        ]
        if let authorAvatarURL, !authorAvatarURL.isEmpty { data["authorAvatarURL"] = authorAvatarURL }
        if let callout { data["callout"] = callout.toFirestore() }
        if let replyTo { data["replyTo"] = replyTo.toFirestore() }
        if let calloutUpdate { data["calloutUpdate"] = calloutUpdate.toFirestore() }
        if let calloutResult { data["calloutResult"] = calloutResult.toFirestore() }
        if let tradeShare { data["tradeShare"] = tradeShare.toFirestore() }
        if let gamePlan { data["gamePlan"] = gamePlan.toFirestore() }
        if let editedAt { data["editedAt"] = Timestamp(date: editedAt) }
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> CommunityMessage {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let channelId = data["channelId"] as? String,
              let communityId = data["communityId"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var message = CommunityMessage(
            content: content,
            authorId: authorId,
            authorUsername: authorUsername,
            channelId: channelId,
            communityId: communityId,
            authorAvatarURL: data["authorAvatarURL"] as? String
        )
        message.id = id
        message.createdAt = createdAtTimestamp.dateValue()
        message.editedAt = (data["editedAt"] as? Timestamp)?.dateValue()
        message.isDeleted = data["isDeleted"] as? Bool ?? false
        message.deletedBy = data["deletedBy"] as? String
        message.deletedAt = (data["deletedAt"] as? Timestamp)?.dateValue()
        message.isPinned = data["isPinned"] as? Bool ?? false
        message.pinnedBy = data["pinnedBy"] as? String
        message.pinnedAt = (data["pinnedAt"] as? Timestamp)?.dateValue()
        if !message.isDeleted {
            if let calloutData = data["callout"] as? [String: Any] {
                message.callout = TradeCallout.fromFirestore(calloutData)
            }
            message.replyTo = (data["replyTo"] as? [String: Any]).flatMap(MessageReplyRef.fromFirestore)
            message.calloutUpdate = (data["calloutUpdate"] as? [String: Any]).flatMap(CalloutUpdate.fromFirestore)
            message.calloutResult = (data["calloutResult"] as? [String: Any]).flatMap(CalloutResult.fromFirestore)
            message.tradeShare = (data["tradeShare"] as? [String: Any]).flatMap(TradeShareInfo.fromFirestore)
            message.gamePlan = (data["gamePlan"] as? [String: Any]).flatMap(GamePlan.fromFirestore)
        }
        return message
    }
}

// MARK: - Chat text limits

/// Keeps text inside the rules' size limits (`content` 4000, `replyTo.preview` 200,
/// `gamePlan.title` 100). Counts UTF-8 bytes, which is never less than the characters
/// the rules count, so a clipped string always passes.
enum ChatText {
    static let contentLimit = 4000
    static let previewLimit = 200
    static let gamePlanTitleLimit = 100

    static func clip(_ text: String, max: Int) -> String {
        guard text.utf8.count > max else { return text }
        let ellipsis = "…"
        let budget = max - ellipsis.utf8.count
        var result = ""
        var used = 0
        for character in text {
            let size = String(character).utf8.count
            if used + size > budget { break }
            result.append(character)
            used += size
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines) + ellipsis
    }
}

// MARK: - Reply reference

/// `replyTo: { messageId, authorId, authorUsername, preview }` on a channel message.
struct MessageReplyRef: Codable, Equatable {
    var messageId: String
    var authorId: String
    var authorUsername: String
    /// At most 200 characters
    var preview: String

    init(messageId: String, authorId: String, authorUsername: String, preview: String) {
        self.messageId = messageId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.preview = ChatText.clip(preview, max: ChatText.previewLimit)
    }

    /// A reference to `message`, with its one-line preview.
    init(to message: CommunityMessage) {
        self.init(messageId: message.id, authorId: message.authorId,
                  authorUsername: message.authorUsername, preview: message.previewText)
    }

    func toFirestore() -> [String: Any] {
        [
            "messageId": messageId,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "preview": ChatText.clip(preview, max: ChatText.previewLimit)
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> MessageReplyRef? {
        guard let messageId = data["messageId"] as? String, !messageId.isEmpty else { return nil }
        return MessageReplyRef(
            messageId: messageId,
            authorId: data["authorId"] as? String ?? "",
            authorUsername: data["authorUsername"] as? String ?? "",
            preview: data["preview"] as? String ?? ""
        )
    }
}

// MARK: - Trade share

/// `tradeShare: { tradeId, ticker, tradeType, entryPrice, quantity, isOpen, exitPrice?, proof, note? }`,
/// copied from the author's own `trades/{tradeId}`. The rules compare every field with the trade doc,
/// so sending builds the map from the raw document (`firestoreData(fromTradeDoc:)`), never from this struct.
struct TradeShareInfo: Codable, Equatable {
    var tradeId: String
    var ticker: String
    /// The trade's `tradeType` as stored: "stock", "option", "crypto" or "forex"
    var tradeType: String
    var entryPrice: Double
    var quantity: Double
    var isOpen: Bool
    var exitPrice: Double?
    var proof: TradeProof
    var note: String?

    var assetType: TradeType? { TradeType(rawValue: tradeType) }

    /// Closed trades only. Same math as the portfolio (`Trade.profitLossPercentage`).
    var resultPercent: Double? {
        guard !isOpen, let exitPrice, entryPrice > 0 else { return nil }
        return (exitPrice - entryPrice) / entryPrice * 100
    }

    /// Plain-text summary used as the message's `content`.
    var summary: String {
        var parts = ["📊 $\(ticker)", assetType?.displayName ?? tradeType.capitalized,
                     "Entry \(TradeCallout.formatPrice(entryPrice))"]
        if isOpen {
            parts.append("Open")
        } else if let exitPrice {
            var exit = "Exit \(TradeCallout.formatPrice(exitPrice))"
            if let result = resultPercent { exit += " (\(TradeCallout.formatPercent(result)))" }
            parts.append(exit)
        }
        parts.append(proof.label)
        var text = parts.joined(separator: " · ")
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            text += "\n\(note)"
        }
        return text
    }

    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "tradeId": tradeId,
            "ticker": ticker,
            "tradeType": tradeType,
            "entryPrice": entryPrice,
            "quantity": quantity,
            "isOpen": isOpen,
            "proof": proof.rawValue
        ]
        if let exitPrice { data["exitPrice"] = exitPrice }
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { data["note"] = note }
        return data
    }

    /// The `tradeShare` map for sending, with each compared value copied as stored on the trade
    /// (same Firestore type), and a missing `proof` read as "self_reported" like the rules do.
    /// Nil when the document is missing a field the rules compare.
    static func firestoreData(fromTradeDoc trade: [String: Any], tradeId: String, note: String?) -> [String: Any]? {
        guard let ticker = trade["ticker"] as? String,
              let tradeType = trade["tradeType"] as? String,
              let entryPrice = trade["entryPrice"], TrackRecordDecode.double(entryPrice) != nil,
              let quantity = trade["quantity"], TrackRecordDecode.double(quantity) != nil,
              let isOpen = trade["isOpen"] as? Bool else { return nil }
        var data: [String: Any] = [
            "tradeId": tradeId,
            "ticker": ticker,
            "tradeType": tradeType,
            "entryPrice": entryPrice,
            "quantity": quantity,
            "isOpen": isOpen,
            "proof": proofValue(trade["proof"])
        ]
        if !isOpen {
            guard let exitPrice = trade["exitPrice"], TrackRecordDecode.double(exitPrice) != nil else { return nil }
            data["exitPrice"] = exitPrice
        }
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            data["note"] = ChatText.clip(note, max: 500)
        }
        return data
    }

    /// The trade's stored `proof` exactly as stored, or "self_reported" when the field is missing
    /// (`trade.get('proof', 'self_reported')` in the rules).
    static func proofValue(_ stored: Any?) -> String {
        (stored as? String) ?? TradeProof.selfReported.rawValue
    }

    static func fromFirestore(_ data: [String: Any]) -> TradeShareInfo? {
        guard let tradeId = data["tradeId"] as? String,
              let ticker = data["ticker"] as? String,
              let entryPrice = TrackRecordDecode.double(data["entryPrice"]) else { return nil }
        return TradeShareInfo(
            tradeId: tradeId,
            ticker: ticker,
            tradeType: data["tradeType"] as? String ?? TradeType.stock.rawValue,
            entryPrice: entryPrice,
            quantity: TrackRecordDecode.double(data["quantity"]) ?? 0,
            isOpen: data["isOpen"] as? Bool ?? true,
            exitPrice: TrackRecordDecode.double(data["exitPrice"]),
            proof: TradeProof(firestoreValue: data["proof"]),
            note: data["note"] as? String
        )
    }
}

// MARK: - Game plan

/// `gamePlan: { title, tickers: [{ symbol, bias, levels?, note? }] }`, 1–15 tickers.
/// A daily watchlist template for leaders, posted from the composer's "+" menu.
struct GamePlan: Codable, Equatable {
    static let maxTickers = 15

    enum Bias: String, Codable, CaseIterable, Identifiable {
        case bullish, bearish, neutral

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }

        var color: Color {
            switch self {
            case .bullish: return .marketGreen
            case .bearish: return .marketRed
            case .neutral: return .secondary
            }
        }

        var icon: String {
            switch self {
            case .bullish: return "arrow.up.right"
            case .bearish: return "arrow.down.right"
            case .neutral: return "arrow.left.and.right"
            }
        }
    }

    struct Entry: Codable, Equatable, Identifiable {
        var id = UUID()
        var symbol: String
        var bias: Bias
        /// Free text, e.g. "180 support / 192 breakout"
        var levels: String?
        var note: String?

        private enum CodingKeys: String, CodingKey { case symbol, bias, levels, note }
    }

    var title: String
    var tickers: [Entry]

    /// "Game plan for Sun, Nov 22"
    static func defaultTitle(for date: Date = Date()) -> String {
        "Game plan for \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
    }

    /// Plain-text summary used as the message's `content`.
    var summary: String {
        var lines = ["🗺️ \(title)"]
        for entry in tickers {
            var line = "$\(entry.symbol) \(entry.bias.rawValue)"
            if let levels = entry.levels, !levels.isEmpty { line += " · \(levels)" }
            if let note = entry.note, !note.isEmpty { line += " · \(note)" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    func toFirestore() -> [String: Any] {
        [
            "title": ChatText.clip(title, max: ChatText.gamePlanTitleLimit),
            "tickers": tickers.prefix(Self.maxTickers).map { entry -> [String: Any] in
                var data: [String: Any] = ["symbol": entry.symbol, "bias": entry.bias.rawValue]
                if let levels = entry.levels, !levels.isEmpty { data["levels"] = levels }
                if let note = entry.note, !note.isEmpty { data["note"] = note }
                return data
            }
        ]
    }

    static func fromFirestore(_ data: [String: Any]) -> GamePlan? {
        guard let title = data["title"] as? String,
              let rows = data["tickers"] as? [[String: Any]] else { return nil }
        let tickers = rows.compactMap { row -> Entry? in
            guard let symbol = row["symbol"] as? String, !symbol.isEmpty else { return nil }
            return Entry(
                symbol: symbol,
                bias: Bias(rawValue: row["bias"] as? String ?? "") ?? .neutral,
                levels: row["levels"] as? String,
                note: row["note"] as? String
            )
        }
        return GamePlan(title: title, tickers: tickers)
    }
}

// MARK: - Enhanced Community Settings with Image Support
struct CommunitySettings {
    var name: String
    var description: String
    var isPrivate: Bool
    
    // ✅ ENHANCED: Support both property naming conventions
    // Store internally as the Community model expects
    private var _avatarURL: String?
    private var _bannerURL: String?
    
    // ✅ ENHANCED: Computed properties for compatibility with UI code
    var profileImageUrl: String? {
        get { return _avatarURL }
        set { _avatarURL = newValue }
    }
    
    var bannerImageUrl: String? {
        get { return _bannerURL }
        set { _bannerURL = newValue }
    }
    
    // ✅ ENHANCED: Direct access properties for Community model mapping
    var avatarURL: String? {
        get { return _avatarURL }
        set { _avatarURL = newValue }
    }
    
    var bannerURL: String? {
        get { return _bannerURL }
        set { _bannerURL = newValue }
    }
    
    // ✅ ENHANCED: Helper computed properties
    var hasAvatarImage: Bool {
        return _avatarURL != nil && !_avatarURL!.isEmpty
    }
    
    var hasBannerImage: Bool {
        return _bannerURL != nil && !_bannerURL!.isEmpty
    }
    
    init(from community: Community) {
        self.name = community.name
        self.description = community.description
        self.isPrivate = community.isPrivate
        
        // ✅ ENHANCED: Map from Community model properties
        self._avatarURL = community.avatarURL
        self._bannerURL = community.bannerURL
    }
    
    // ✅ ENHANCED: Initialize with empty values for new communities
    init() {
        self.name = ""
        self.description = ""
        self.isPrivate = false
        self._avatarURL = nil
        self._bannerURL = nil
    }
    
    // ✅ ENHANCED: Convert back to community for updates with proper mapping
    func updateCommunity(_ community: Community) -> Community {
        var updatedCommunity = community
        updatedCommunity.name = self.name
        updatedCommunity.description = self.description
        updatedCommunity.isPrivate = self.isPrivate
        
        // ✅ ENHANCED: Map back to Community model properties
        updatedCommunity.avatarURL = self._avatarURL
        updatedCommunity.bannerURL = self._bannerURL
        
        return updatedCommunity
    }
    
    // ✅ ENHANCED: Validation methods
    func isValidForSave() -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               name.count >= 3 &&
               description.count >= 10
    }
    
    func validationMessage() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Community name is required"
        }
        if name.count < 3 {
            return "Community name must be at least 3 characters"
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Community description is required"
        }
        if description.count < 10 {
            return "Community description must be at least 10 characters"
        }
        return nil
    }
    
    // ✅ ENHANCED: Clear image methods
    mutating func clearAvatar() {
        self._avatarURL = nil
    }
    
    mutating func clearBanner() {
        self._bannerURL = nil
    }
    
    // ✅ ENHANCED: Set image URLs
    mutating func setAvatarURL(_ url: String?) {
        self._avatarURL = url
    }
    
    mutating func setBannerURL(_ url: String?) {
        self._bannerURL = url
    }
}

// MARK: - Community Role Enum (Enhanced)
enum CommunityRole: String, CaseIterable, Codable {
    case owner = "owner"
    case admin = "admin"
    case moderator = "moderator"
    case member = "member"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .moderator: return "Moderator"
        case .member: return "Member"
        }
    }
    
    var color: Color {
        switch self {
        case .owner: return .goldText
        case .admin: return .warning
        case .moderator: return .stockColor
        case .member: return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "star.fill"
        case .moderator: return "shield.fill"
        case .member: return "person.fill"
        }
    }
    
    // Role hierarchy for permissions
    var hierarchyLevel: Int {
        switch self {
        case .owner: return 4
        case .admin: return 3
        case .moderator: return 2
        case .member: return 1
        }
    }
    
    // ✅ ENHANCED: Additional role methods
    var canManageImages: Bool {
        return hierarchyLevel >= 4 // Only owners can manage community images
    }
    
    var canManageSettings: Bool {
        return hierarchyLevel >= 4 // Only owners can manage settings
    }
    
    var canManageMembers: Bool {
        return hierarchyLevel >= 3 // Admins and above can manage members
    }
    
    var canManageChannels: Bool {
        return hierarchyLevel >= 3 // Admins and above can manage channels
    }
    
    // Can this role manage the target role?
    func canManage(_ targetRole: CommunityRole) -> Bool {
        return self.hierarchyLevel > targetRole.hierarchyLevel
    }
}

// MARK: - Enhanced Community Member With Role
struct CommunityMemberWithRole: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let username: String
    let fullName: String
    let role: CommunityRole
    let joinedAt: Date
    
    // ✅ ENHANCED: Additional properties
    var profileImageUrl: String?
    var isVerified: Bool
    var lastActiveAt: Date?
    
    init(userId: String, username: String, fullName: String, role: CommunityRole = .member, joinedAt: Date = Date(), profileImageUrl: String? = nil, isVerified: Bool = false) {
        self.id = userId
        self.userId = userId
        self.username = username
        self.fullName = fullName
        self.role = role
        self.joinedAt = joinedAt
        self.profileImageUrl = profileImageUrl
        self.isVerified = isVerified
        self.lastActiveAt = nil
    }
    
    // ✅ ENHANCED: Computed properties
    var initials: String {
        let components = fullName.components(separatedBy: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else {
            return String(fullName.prefix(2)).uppercased()
        }
    }
    
    var displayName: String {
        if !fullName.isEmpty { return fullName }
        return username.isEmpty ? "Unknown member" : username
    }
    
    var timeInCommunity: String {
        let now = Date()
        let interval = now.timeIntervalSince(joinedAt)
        let days = Int(interval / 86400)
        
        if days < 1 {
            return "Joined today"
        } else if days < 30 {
            return "Joined \(days) day\(days == 1 ? "" : "s") ago"
        } else if days < 365 {
            let months = Int(days / 30)
            return "Joined \(months) month\(months == 1 ? "" : "s") ago"
        } else {
            let years = Int(days / 365)
            return "Joined \(years) year\(years == 1 ? "" : "s") ago"
        }
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "username": username,
            "fullName": fullName,
            "role": role.rawValue,
            "joinedAt": Timestamp(date: joinedAt),
            "isVerified": isVerified
        ]
        
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        if let lastActiveAt = lastActiveAt {
            data["lastActiveAt"] = Timestamp(date: lastActiveAt)
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any]) throws -> CommunityMemberWithRole {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let fullName = data["fullName"] as? String,
              let roleString = data["role"] as? String,
              let role = CommunityRole(rawValue: roleString),
              let joinedAtTimestamp = data["joinedAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var member = CommunityMemberWithRole(
            userId: userId,
            username: username,
            fullName: fullName,
            role: role,
            joinedAt: joinedAtTimestamp.dateValue(),
            profileImageUrl: data["profileImageUrl"] as? String,
            isVerified: data["isVerified"] as? Bool ?? false
        )
        
        if let lastActiveTimestamp = data["lastActiveAt"] as? Timestamp {
            member.lastActiveAt = lastActiveTimestamp.dateValue()
        }
        
        return member
    }
    
    // ✅ ENHANCED: Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CommunityMemberWithRole, rhs: CommunityMemberWithRole) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Enhanced Community Rule
struct CommunityRule: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String
    var isRequired: Bool // Must acknowledge to join
    var order: Int // Display order
    var isDefault: Bool // Default rule (can't be deleted)
    var createdAt: Date
    var category: String? // Rule category (e.g., "Trading", "Behavior", "Content")
    var iconName: String? // Optional icon for the rule
    
    // ✅ ENHANCED: Additional properties
    var isActive: Bool
    var violationCount: Int
    var lastUpdated: Date?
    
    init(title: String, description: String, isRequired: Bool = true, order: Int = 0, isDefault: Bool = false, category: String? = nil, iconName: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.isRequired = isRequired
        self.order = order
        self.isDefault = isDefault
        self.createdAt = Date()
        self.category = category
        self.iconName = iconName
        self.isActive = true
        self.violationCount = 0
        self.lastUpdated = nil
    }
    
    // ✅ ENHANCED: Computed properties
    var categoryIcon: String {
        guard let category = category else { return "doc.text" }
        
        switch category.lowercased() {
        case "legal": return "scale.3d"
        case "risk management": return "shield.fill"
        case "trading content": return "chart.bar.fill"
        case "content policy": return "doc.plaintext"
        case "behavior": return "person.2.fill"
        default: return iconName ?? "doc.text"
        }
    }
    
    var categoryColor: Color {
        guard let category = category else { return .blue }
        
        switch category.lowercased() {
        case "legal": return .red
        case "risk management": return .orange
        case "trading content": return .green
        case "content policy": return .purple
        case "behavior": return .blue
        default: return .gray
        }
    }
    
    var priorityLevel: Int {
        if isRequired && isDefault {
            return 3 // Highest priority
        } else if isRequired {
            return 2 // High priority
        } else {
            return 1 // Normal priority
        }
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "description": description,
            "isRequired": isRequired,
            "order": order,
            "isDefault": isDefault,
            "createdAt": Timestamp(date: createdAt),
            "isActive": isActive,
            "violationCount": violationCount
        ]
        
        if let category = category {
            data["category"] = category
        }
        if let iconName = iconName {
            data["iconName"] = iconName
        }
        if let lastUpdated = lastUpdated {
            data["lastUpdated"] = Timestamp(date: lastUpdated)
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> CommunityRule {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let isRequired = data["isRequired"] as? Bool,
              let order = data["order"] as? Int,
              let isDefault = data["isDefault"] as? Bool,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var rule = CommunityRule(
            title: title,
            description: description,
            isRequired: isRequired,
            order: order,
            isDefault: isDefault,
            category: data["category"] as? String,
            iconName: data["iconName"] as? String
        )
        rule.id = id
        rule.createdAt = createdAtTimestamp.dateValue()
        rule.isActive = data["isActive"] as? Bool ?? true
        rule.violationCount = data["violationCount"] as? Int ?? 0
        
        if let lastUpdatedTimestamp = data["lastUpdated"] as? Timestamp {
            rule.lastUpdated = lastUpdatedTimestamp.dateValue()
        }
        
        return rule
    }
    
    // ✅ ENHANCED: Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CommunityRule, rhs: CommunityRule) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Enhanced Default Financial Disclaimer Rules
    static func getDefaultTradingRules() -> [CommunityRule] {
        return [
            CommunityRule(
                title: "⚠️ Not Financial Advice",
                description: "All content shared in this community is for educational and informational purposes only. Nothing shared here constitutes financial, investment, or trading advice. All trading involves substantial risk of loss. You are solely responsible for your own trading decisions.",
                isRequired: true,
                order: 1,
                isDefault: true,
                category: "Legal",
                iconName: "exclamationmark.triangle.fill"
            ),
            
            CommunityRule(
                title: "🚨 Risk Disclaimer",
                description: "Trading stocks, options, crypto, and other financial instruments involves significant risk of loss. Past performance does not guarantee future results. Never trade with money you cannot afford to lose. All members trade at their own risk.",
                isRequired: true,
                order: 2,
                isDefault: true,
                category: "Risk Management",
                iconName: "shield.slash.fill"
            ),
            
            CommunityRule(
                title: "📊 Trade Documentation",
                description: "When sharing trades or callouts, please provide clear entry/exit points, position size, and risk management details. This helps maintain educational value and transparency for the community.",
                isRequired: false,
                order: 3,
                isDefault: true,
                category: "Trading Content",
                iconName: "chart.bar.doc.horizontal"
            ),
            
            CommunityRule(
                title: "🚫 No Pump & Dump",
                description: "Promoting securities with intent to artificially inflate prices is strictly prohibited. Share genuine analysis and educational content only. Misleading or manipulative content will result in immediate removal.",
                isRequired: true,
                order: 4,
                isDefault: true,
                category: "Content Policy",
                iconName: "hand.raised.slash.fill"
            ),
            
            CommunityRule(
                title: "🤝 Respectful Communication",
                description: "Maintain respectful dialogue even during disagreements. No harassment, personal attacks, or offensive language. We're here to learn from each other and improve our trading skills together.",
                isRequired: true,
                order: 5,
                isDefault: true,
                category: "Behavior",
                iconName: "person.2.fill"
            )
        ]
    }
}

// MARK: - Enhanced Community Moderation Settings
struct CommunityModerationSettings: Codable {
    var autoModEnabled: Bool
    var requireApproval: Bool // For new members
    var bannedWords: [String]
    var maxMessagesPerMinute: Int
    var linkPostingAllowed: Bool
    var imagePostingAllowed: Bool
    
    // ✅ ENHANCED: Additional moderation settings
    var slowModeEnabled: Bool
    var slowModeInterval: TimeInterval // in seconds
    var autoDeleteSpam: Bool
    var requireEmailVerification: Bool
    var minimumAccountAge: TimeInterval // in seconds
    var allowedFileTypes: [String]
    var maxFileSize: Int // in bytes
    
    init() {
        self.autoModEnabled = true
        self.requireApproval = false
        self.bannedWords = []
        self.maxMessagesPerMinute = 10
        self.linkPostingAllowed = true
        self.imagePostingAllowed = true
        self.slowModeEnabled = false
        self.slowModeInterval = 30
        self.autoDeleteSpam = true
        self.requireEmailVerification = false
        self.minimumAccountAge = 0
        self.allowedFileTypes = ["jpg", "jpeg", "png", "gif", "webp"]
        self.maxFileSize = 10 * 1024 * 1024 // 10MB
    }
    
    // ✅ ENHANCED: Computed properties
    var isStrictMode: Bool {
        return autoModEnabled && requireApproval && slowModeEnabled && requireEmailVerification
    }
    
    var moderationLevel: String {
        if isStrictMode {
            return "Strict"
        } else if autoModEnabled && (requireApproval || slowModeEnabled) {
            return "Moderate"
        } else if autoModEnabled {
            return "Basic"
        } else {
            return "Disabled"
        }
    }
    
    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "autoModEnabled": autoModEnabled,
            "requireApproval": requireApproval,
            "bannedWords": bannedWords,
            "maxMessagesPerMinute": maxMessagesPerMinute,
            "linkPostingAllowed": linkPostingAllowed,
            "imagePostingAllowed": imagePostingAllowed,
            "slowModeEnabled": slowModeEnabled,
            "slowModeInterval": slowModeInterval,
            "autoDeleteSpam": autoDeleteSpam,
            "requireEmailVerification": requireEmailVerification,
            "minimumAccountAge": minimumAccountAge,
            "allowedFileTypes": allowedFileTypes,
            "maxFileSize": maxFileSize
        ]
    }
    
    static func fromFirestore(data: [String: Any]) throws -> CommunityModerationSettings {
        var settings = CommunityModerationSettings()
        
        settings.autoModEnabled = data["autoModEnabled"] as? Bool ?? true
        settings.requireApproval = data["requireApproval"] as? Bool ?? false
        settings.bannedWords = data["bannedWords"] as? [String] ?? []
        settings.maxMessagesPerMinute = data["maxMessagesPerMinute"] as? Int ?? 10
        settings.linkPostingAllowed = data["linkPostingAllowed"] as? Bool ?? true
        settings.imagePostingAllowed = data["imagePostingAllowed"] as? Bool ?? true
        settings.slowModeEnabled = data["slowModeEnabled"] as? Bool ?? false
        settings.slowModeInterval = data["slowModeInterval"] as? TimeInterval ?? 30
        settings.autoDeleteSpam = data["autoDeleteSpam"] as? Bool ?? true
        settings.requireEmailVerification = data["requireEmailVerification"] as? Bool ?? false
        settings.minimumAccountAge = data["minimumAccountAge"] as? TimeInterval ?? 0
        settings.allowedFileTypes = data["allowedFileTypes"] as? [String] ?? ["jpg", "jpeg", "png", "gif", "webp"]
        settings.maxFileSize = data["maxFileSize"] as? Int ?? 10 * 1024 * 1024
        
        return settings
    }
}
