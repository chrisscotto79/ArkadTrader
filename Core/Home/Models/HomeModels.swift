//
//  HomeModels.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//

// File: Core/Home/Models/HomeModels.swift
// Complete models for all home functionality

import Foundation
import FirebaseFirestore

// MARK: - Post Model
struct Post: Identifiable, Codable, Equatable {
    let id: String
    let authorId: String
    let authorUsername: String
    let authorProfileImageUrl: String?
    let content: String
    let postType: PostType
    let createdAt: Date
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    let hashtags: [String]
    let mentionedUsers: [String]
    let imageUrls: [String]
    let tickerSymbols: [String]
    
    init(id: String = UUID().uuidString, authorId: String, authorUsername: String, authorProfileImageUrl: String? = nil, content: String, postType: PostType, createdAt: Date = Date(), likesCount: Int = 0, commentsCount: Int = 0, sharesCount: Int = 0, hashtags: [String] = [], mentionedUsers: [String] = [], imageUrls: [String] = [], tickerSymbols: [String] = []) {
        self.id = id
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorProfileImageUrl = authorProfileImageUrl
        self.content = content
        self.postType = postType
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.hashtags = hashtags
        self.mentionedUsers = mentionedUsers
        self.imageUrls = imageUrls
        self.tickerSymbols = tickerSymbols
    }
    
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - PostType Enum
enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case tradeResult = "tradeResult"
    case marketAnalysis = "marketAnalysis"
    case question = "question"
    case news = "news"
    
    var displayName: String {
        switch self {
        case .text: return "Post"
        case .tradeResult: return "Trade Result"
        case .marketAnalysis: return "Market Analysis"
        case .question: return "Question"
        case .news: return "News"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar.doc.horizontal"
        case .question: return "questionmark.circle"
        case .news: return "newspaper"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .tradeResult: return "green"
        case .marketAnalysis: return "orange"
        case .question: return "purple"
        case .news: return "red"
        }
    }
    
    var placeholder: String {
        switch self {
        case .text:
            return "What's on your mind? Share your thoughts with the community..."
        case .tradeResult:
            return "Share your latest trade results. Include ticker, entry/exit prices, and what you learned..."
        case .marketAnalysis:
            return "Share your market analysis and insights. What do you see in the charts or fundamentals?"
        case .question:
            return "Ask the community a question about trading, markets, or strategies..."
        case .news:
            return "Share important market news or updates..."
        }
    }
    
    var tips: String {
        switch self {
        case .text:
            return "💡 Tip: Use hashtags and mention users with @ to increase engagement"
        case .tradeResult:
            return "💡 Tip: Include #trade, ticker symbols, and profit/loss details"
        case .marketAnalysis:
            return "💡 Tip: Use #analysis and tag relevant stocks or sectors"
        case .question:
            return "💡 Tip: Be specific and use relevant hashtags for better answers"
        case .news:
            return "💡 Tip: Include source links and relevant tickers"
        }
    }
}



// MARK: - Comment Model
struct Comment: Identifiable, Codable, Equatable {
    let id: String
    let postId: String
    let authorId: String
    let authorUsername: String
    let authorProfileImageUrl: String?
    let content: String
    let createdAt: Date
    var likesCount: Int
    let parentCommentId: String? // For replies
    let mentionedUsers: [String]
    
    init(id: String = UUID().uuidString, postId: String, authorId: String, authorUsername: String, authorProfileImageUrl: String? = nil, content: String, createdAt: Date = Date(), likesCount: Int = 0, parentCommentId: String? = nil, mentionedUsers: [String] = []) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorProfileImageUrl = authorProfileImageUrl
        self.content = content
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.parentCommentId = parentCommentId
        self.mentionedUsers = mentionedUsers
    }
    
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Comment Sort Options
enum CommentSortOption: String, CaseIterable {
    case recent = "recent"
    case top = "top"
    case oldest = "oldest"
    
    var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .top: return "Top"
        case .oldest: return "Oldest"
        }
    }
    
    var icon: String {
        switch self {
        case .recent: return "clock"
        case .top: return "arrow.up.circle"
        case .oldest: return "clock.arrow.2.circlepath"
        }
    }
}

// MARK: - Market News Article Model
struct MarketNewsArticle: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let publishedUtc: Date
    let articleUrl: String?
    let description: String?
    let keywords: [String]
    let imageUrl: String?
    let cachedAt: Date
    let source: String?
    let category: String?
    let tickerSymbols: [String]
    let sentiment: NewsSentiment?
    
    init(id: String = UUID().uuidString, title: String, summary: String? = nil, publishedUtc: Date, articleUrl: String? = nil, description: String? = nil, keywords: [String] = [], imageUrl: String? = nil, cachedAt: Date = Date(), source: String? = nil, category: String? = nil, tickerSymbols: [String] = [], sentiment: NewsSentiment? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.publishedUtc = publishedUtc
        self.articleUrl = articleUrl
        self.description = description
        self.keywords = keywords
        self.imageUrl = imageUrl
        self.cachedAt = cachedAt
        self.source = source
        self.category = category
        self.tickerSymbols = tickerSymbols
        self.sentiment = sentiment
    }
    
    static func == (lhs: MarketNewsArticle, rhs: MarketNewsArticle) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - News Sentiment
enum NewsSentiment: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    
    var color: String {
        switch self {
        case .positive: return "green"
        case .negative: return "red"
        case .neutral: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "arrow.up.circle.fill"
        case .negative: return "arrow.down.circle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
}

// MARK: - Post Filter Options
enum PostFilter: CaseIterable, Equatable {
    case all
    case trades
    case analysis
    case questions
    case news
    case hashtag(String)
    case ticker(String)
    case user(String)
    
    var title: String {
        switch self {
        case .all: return "All"
        case .trades: return "Trades"
        case .analysis: return "Analysis"
        case .questions: return "Questions"
        case .news: return "News"
        case .hashtag(let tag): return "#\(tag)"
        case .ticker(let symbol): return "$\(symbol)"
        case .user(let username): return "@\(username)"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .analysis: return "chart.bar.doc.horizontal"
        case .questions: return "questionmark.circle"
        case .news: return "newspaper"
        case .hashtag: return "number"
        case .ticker: return "dollarsign.circle"
        case .user: return "person.circle"
        }
    }
    
    func matches(post: Post) -> Bool {
        switch self {
        case .all:
            return true
        case .trades:
            return post.postType == .tradeResult
        case .analysis:
            return post.postType == .marketAnalysis
        case .questions:
            return post.postType == .question
        case .news:
            return post.postType == .news
        case .hashtag(let tag):
            return post.hashtags.contains(tag.lowercased())
        case .ticker(let symbol):
            return post.tickerSymbols.contains(symbol.uppercased())
        case .user(let username):
            return post.authorUsername.lowercased() == username.lowercased()
        }
    }
    
    static var allCases: [PostFilter] {
        return [.all, .trades, .analysis, .questions, .news]
    }
    
    static func == (lhs: PostFilter, rhs: PostFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.trades, .trades), (.analysis, .analysis), (.questions, .questions), (.news, .news):
            return true
        case (.hashtag(let tag1), .hashtag(let tag2)):
            return tag1 == tag2
        case (.ticker(let symbol1), .ticker(let symbol2)):
            return symbol1 == symbol2
        case (.user(let user1), .user(let user2)):
            return user1 == user2
        default:
            return false
        }
    }
}

// MARK: - User Interaction Models
struct UserInteraction: Codable {
    let userId: String
    let postId: String
    let interactionType: InteractionType
    let createdAt: Date
    
    enum InteractionType: String, Codable {
        case like = "like"
        case bookmark = "bookmark"
        case share = "share"
        case report = "report"
        case view = "view"
    }
}

// MARK: - Report Models
struct PostReport: Codable {
    let id: String
    let postId: String
    let reportedBy: String
    let reason: ReportReason
    let additionalDetails: String?
    let createdAt: Date
    let status: ReportStatus
    
    enum ReportReason: String, CaseIterable, Codable {
        case spam = "spam"
        case harassment = "harassment"
        case falseInformation = "false_information"
        case inappropriateContent = "inappropriate_content"
        case copyrightViolation = "copyright_violation"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .spam: return "Spam"
            case .harassment: return "Harassment"
            case .falseInformation: return "False Information"
            case .inappropriateContent: return "Inappropriate Content"
            case .copyrightViolation: return "Copyright Violation"
            case .other: return "Other"
            }
        }
        
        var description: String {
            switch self {
            case .spam: return "Unwanted commercial content or repetitive posts"
            case .harassment: return "Bullying, threats, or abusive behavior"
            case .falseInformation: return "Misleading or false market information"
            case .inappropriateContent: return "Content that violates community guidelines"
            case .copyrightViolation: return "Unauthorized use of copyrighted material"
            case .other: return "Other violation not listed above"
            }
        }
    }
    
    enum ReportStatus: String, Codable {
        case pending = "pending"
        case reviewed = "reviewed"
        case resolved = "resolved"
        case dismissed = "dismissed"
    }
}

// MARK: - Share Options
enum ShareOption: String, CaseIterable {
    case copyLink = "copy_link"
    case shareToStory = "share_to_story"
    case shareExternal = "share_external"
    
    var displayName: String {
        switch self {
        case .copyLink: return "Copy Link"
        case .shareToStory: return "Share to Story"
        case .shareExternal: return "Share..."
        }
    }
    
    var icon: String {
        switch self {
        case .copyLink: return "link"
        case .shareToStory: return "plus.circle"
        case .shareExternal: return "square.and.arrow.up"
        }
    }
}
enum PostFilter: Equatable, Hashable {
    case all
    case trades
    case analysis
    case questions
    case news
    case hashtag(String)
    case ticker(String)
    case user(String)
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .trades: return "Trades"
        case .analysis: return "Analysis"
        case .questions: return "Questions"
        case .news: return "News"
        case .hashtag(let tag): return "#\(tag)"
        case .ticker(let symbol): return "$\(symbol)"
        case .user(let username): return "@\(username)"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .trades: return "chart.line.uptrend.xyaxis"
        case .analysis: return "chart.bar.doc.horizontal"
        case .questions: return "questionmark.circle"
        case .news: return "newspaper"
        case .hashtag: return "number"
        case .ticker: return "dollarsign.circle"
        case .user: return "person.circle"
        }
    }
    
    func matches(post: Post) -> Bool {
        switch self {
        case .all:
            return true
        case .trades:
            return post.postType == .tradeResult
        case .analysis:
            return post.postType == .marketAnalysis
        case .questions:
            return post.postType == .question
        case .news:
            return post.postType == .news
        case .hashtag(let tag):
            return post.hashtags.contains(tag.lowercased())
        case .ticker(let symbol):
            return post.tickerSymbols.contains(symbol.uppercased())
        case .user(let username):
            return post.authorUsername.lowercased() == username.lowercased()
        }
    }
}

// MARK: - PostType Enum
enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case tradeResult = "tradeResult"
    case marketAnalysis = "marketAnalysis"
    case question = "question"
    case news = "news"
    
    var displayName: String {
        switch self {
        case .text: return "Post"
        case .tradeResult: return "Trade Result"
        case .marketAnalysis: return "Market Analysis"
        case .question: return "Question"
        case .news: return "News"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar.doc.horizontal"
        case .question: return "questionmark.circle"
        case .news: return "newspaper"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .tradeResult: return "green"
        case .marketAnalysis: return "orange"
        case .question: return "purple"
        case .news: return "red"
        }
    }
    
    var placeholder: String {
        switch self {
        case .text:
            return "What's on your mind? Share your thoughts with the community..."
        case .tradeResult:
            return "Share your latest trade results. Include ticker, entry/exit prices, and what you learned..."
        case .marketAnalysis:
            return "Share your market analysis and insights. What do you see in the charts or fundamentals?"
        case .question:
            return "Ask the community a question about trading, markets, or strategies..."
        case .news:
            return "Share important market news or updates..."
        }
    }
}

// MARK: - CommentSortOption Enum
enum CommentSortOption: String, CaseIterable {
    case recent = "recent"
    case top = "top"
    case oldest = "oldest"
    
    var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .top: return "Top"
        case .oldest: return "Oldest"
        }
    }
    
    var icon: String {
        switch self {
        case .recent: return "clock"
        case .top: return "arrow.up.circle"
        case .oldest: return "clock.arrow.2.circlepath"
        }
    }
}

// MARK: - ShareOption Enum
enum ShareOption: String, CaseIterable {
    case copyLink = "copy_link"
    case shareToStory = "share_to_story"
    case shareToTwitter = "share_to_twitter"
    case shareToLinkedIn = "share_to_linkedin"
    case shareToTelegram = "share_to_telegram"
    case shareToWhatsApp = "share_to_whatsapp"
    case shareToEmail = "share_to_email"
    case shareToMessages = "share_to_messages"
    
    var displayName: String {
        switch self {
        case .copyLink: return "Copy Link"
        case .shareToStory: return "Share to Story"
        case .shareToTwitter: return "Share to Twitter"
        case .shareToLinkedIn: return "Share to LinkedIn"
        case .shareToTelegram: return "Share to Telegram"
        case .shareToWhatsApp: return "Share to WhatsApp"
        case .shareToEmail: return "Share via Email"
        case .shareToMessages: return "Share to Messages"
        }
    }
    
    var icon: String {
        switch self {
        case .copyLink: return "link"
        case .shareToStory: return "camera.circle"
        case .shareToTwitter: return "at"
        case .shareToLinkedIn: return "briefcase"
        case .shareToTelegram: return "paperplane"
        case .shareToWhatsApp: return "message"
        case .shareToEmail: return "envelope"
        case .shareToMessages: return "message.fill"
        }
    }
    
    var color: String {
        switch self {
        case .copyLink: return "blue"
        case .shareToStory: return "purple"
        case .shareToTwitter: return "blue"
        case .shareToLinkedIn: return "blue"
        case .shareToTelegram: return "blue"
        case .shareToWhatsApp: return "green"
        case .shareToEmail: return "gray"
        case .shareToMessages: return "blue"
        }
    }
}

// MARK: - EngagementStats Struct
struct EngagementStats {
    let totalPosts: Int
    let totalLikes: Int
    let totalComments: Int
    let totalShares: Int
    let totalViews: Int
    let averageEngagement: Double
    let topHashtags: [String]
    let topTickers: [String]
    
    init(totalPosts: Int, totalLikes: Int, totalComments: Int, totalShares: Int, totalViews: Int, topHashtags: [String] = [], topTickers: [String] = []) {
        self.totalPosts = totalPosts
        self.totalLikes = totalLikes
        self.totalComments = totalComments
        self.totalShares = totalShares
        self.totalViews = totalViews
        self.topHashtags = topHashtags
        self.topTickers = topTickers
        
        // Calculate average engagement
        let totalEngagement = totalLikes + totalComments + totalShares
        self.averageEngagement = totalPosts > 0 ? Double(totalEngagement) / Double(totalPosts) : 0.0
    }
}

// MARK: - FinnhubNewsResponse Struct
struct FinnhubNewsResponse: Codable {
    let headline: String
    let summary: String
    let url: String
    let image: String
    let source: String
    let datetime: Int
    let category: String
    let related: String?
    
    enum CodingKeys: String, CodingKey {
        case headline, summary, url, image, source, datetime, category, related
    }
}

// MARK: - PostReport Struct
struct PostReport: Codable {
    let id: String
    let postId: String
    let reportedBy: String
    let reason: ReportReason
    let additionalDetails: String?
    let createdAt: Date
    let status: ReportStatus
    
    enum ReportReason: String, CaseIterable, Codable {
        case spam = "spam"
        case harassment = "harassment"
        case inappropriateContent = "inappropriate_content"
        case misinformation = "misinformation"
        case copyrightViolation = "copyright_violation"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .spam: return "Spam"
            case .harassment: return "Harassment"
            case .inappropriateContent: return "Inappropriate Content"
            case .misinformation: return "Misinformation"
            case .copyrightViolation: return "Copyright Violation"
            case .other: return "Other"
            }
        }
    }
    
    enum ReportStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case reviewed = "reviewed"
        case resolved = "resolved"
        case dismissed = "dismissed"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .reviewed: return "Reviewed"
            case .resolved: return "Resolved"
            case .dismissed: return "Dismissed"
            }
        }
    }
}

// MARK: - ActivityItem Struct (for compatibility)
struct ActivityItem: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let activityType: ActivityType
    let content: String
    let relatedId: String?
    let createdAt: Date
    
    init(id: String = UUID().uuidString, userId: String, username: String, activityType: ActivityType, content: String, relatedId: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.username = username
        self.activityType = activityType
        self.content = content
        self.relatedId = relatedId
        self.createdAt = createdAt
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "activityType": activityType.rawValue,
            "content": content,
            "relatedId": relatedId as Any,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> ActivityItem {
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let activityTypeString = data["activityType"] as? String,
              let activityType = ActivityType(rawValue: activityTypeString),
              let content = data["content"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        return ActivityItem(
            id: id,
            userId: userId,
            username: username,
            activityType: activityType,
            content: content,
            relatedId: data["relatedId"] as? String,
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}

// MARK: - Following Activity Model
struct FollowingActivity: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let activityType: ActivityType
    let content: String?
    let relatedPostId: String?
    let timestamp: Date
    
    enum ActivityType: String, Codable {
        case newPost = "new_post"
        case newTrade = "new_trade"
        case tradeClosed = "trade_closed"
        case likedPost = "liked_post"
        case commentedOnPost = "commented_on_post"
        case followedUser = "followed_user"
        
        var description: String {
            switch self {
            case .newPost: return "posted"
            case .newTrade: return "opened a trade"
            case .tradeClosed: return "closed a trade"
            case .likedPost: return "liked a post"
            case .commentedOnPost: return "commented on a post"
            case .followedUser: return "followed a user"
            }
        }
        
        var icon: String {
            switch self {
            case .newPost: return "plus.circle"
            case .newTrade: return "chart.line.uptrend.xyaxis"
            case .tradeClosed: return "checkmark.circle"
            case .likedPost: return "heart"
            case .commentedOnPost: return "message"
            case .followedUser: return "person.badge.plus"
            }
        }
    }
}

// MARK: - Notification Models
struct AppNotification: Identifiable, Codable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let message: String
    let relatedPostId: String?
    let relatedUserId: String?
    let relatedUsername: String?
    let createdAt: Date
    let isRead: Bool
    let actionUrl: String?
    
    enum NotificationType: String, Codable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
        case mention = "mention"
        case reply = "reply"
        case tradeAlert = "trade_alert"
        case marketNews = "market_news"
        
        var icon: String {
            switch self {
            case .like: return "heart.fill"
            case .comment: return "message.fill"
            case .follow: return "person.badge.plus.fill"
            case .mention: return "at.circle.fill"
            case .reply: return "arrowshape.turn.up.left.fill"
            case .tradeAlert: return "chart.line.uptrend.xyaxis.circle.fill"
            case .marketNews: return "newspaper.fill"
            }
        }
        
        var color: String {
            switch self {
            case .like: return "red"
            case .comment: return "blue"
            case .follow: return "green"
            case .mention: return "orange"
            case .reply: return "purple"
            case .tradeAlert: return "arkadGold"
            case .marketNews: return "gray"
            }
        }
    }
}

// MARK: - Supporting Models
struct EngagementStats {
    let totalPosts: Int
    let totalLikes: Int
    let totalComments: Int
    let totalShares: Int
    let totalViews: Int
    let engagementRate: Double
    
    init(totalPosts: Int, totalLikes: Int, totalComments: Int, totalShares: Int, totalViews: Int) {
        self.totalPosts = totalPosts
        self.totalLikes = totalLikes
        self.totalComments = totalComments
        self.totalShares = totalShares
        self.totalViews = totalViews
        
        let totalEngagements = totalLikes + totalComments + totalShares
        self.engagementRate = totalViews > 0 ? Double(totalEngagements) / Double(totalViews) : 0.0
    }
}

struct FinnhubNewsResponse: Codable {
    let headline: String
    let summary: String
    let datetime: Int
    let url: String
    let image: String?
    let source: String
    let category: String
    let related: String? // Ticker symbols
}

// MARK: - Firestore Codable Extensions
extension Post {
    enum CodingKeys: String, CodingKey {
        case id, authorId, authorUsername, authorProfileImageUrl, content, postType, createdAt, likesCount, commentsCount, sharesCount, hashtags, mentionedUsers, imageUrls, tickerSymbols
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorUsername = try container.decode(String.self, forKey: .authorUsername)
        authorProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .authorProfileImageUrl)
        content = try container.decode(String.self, forKey: .content)
        
        let postTypeString = try container.decode(String.self, forKey: .postType)
        postType = PostType(rawValue: postTypeString) ?? .text
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        sharesCount = try container.decodeIfPresent(Int.self, forKey: .sharesCount) ?? 0
        hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        mentionedUsers = try container.decodeIfPresent([String].self, forKey: .mentionedUsers) ?? []
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        tickerSymbols = try container.decodeIfPresent([String].self, forKey: .tickerSymbols) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorUsername, forKey: .authorUsername)
        try container.encodeIfPresent(authorProfileImageUrl, forKey: .authorProfileImageUrl)
        try container.encode(content, forKey: .content)
        try container.encode(postType.rawValue, forKey: .postType)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(likesCount, forKey: .likesCount)
        try container.encode(commentsCount, forKey: .commentsCount)
        try container.encode(sharesCount, forKey: .sharesCount)
        try container.encode(hashtags, forKey: .hashtags)
        try container.encode(mentionedUsers, forKey: .mentionedUsers)
        try container.encode(imageUrls, forKey: .imageUrls)
        try container.encode(tickerSymbols, forKey: .tickerSymbols)
    }
}

extension Comment {
    enum CodingKeys: String, CodingKey {
        case id, postId, authorId, authorUsername, authorProfileImageUrl, content, createdAt, likesCount, parentCommentId, mentionedUsers
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorUsername = try container.decode(String.self, forKey: .authorUsername)
        authorProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .authorProfileImageUrl)
        content = try container.decode(String.self, forKey: .content)
        
        if let timestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        parentCommentId = try container.decodeIfPresent(String.self, forKey: .parentCommentId)
        mentionedUsers = try container.decodeIfPresent([String].self, forKey: .mentionedUsers) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(postId, forKey: .postId)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorUsername, forKey: .authorUsername)
        try container.encodeIfPresent(authorProfileImageUrl, forKey: .authorProfileImageUrl)
        try container.encode(content, forKey: .content)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(likesCount, forKey: .likesCount)
        try container.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
        try container.encode(mentionedUsers, forKey: .mentionedUsers)
    }
}
