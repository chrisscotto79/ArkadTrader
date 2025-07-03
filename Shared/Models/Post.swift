// File: Shared/Models/Post.swift
// Post model for Firebase integration

import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    let id: UUID
    var content: String
    var imageURL: String?
    var authorId: String
    var authorUsername: String
    var authorProfileImageURL: String?
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var isPremiumContent: Bool
    var postType: PostType
    var communityId: String?
    var visibility: PostVisibility
    var hashtags: [String]
    var mentionedUsers: [String]
    var attachedTradeId: String?
    
    init(content: String, authorId: String, authorUsername: String) {
        self.id = UUID()
        self.content = content
        self.imageURL = nil
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorProfileImageURL = nil
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.isPremiumContent = false
        self.postType = .text
        self.communityId = nil
        self.visibility = .public
        self.hashtags = []
        self.mentionedUsers = []
        self.attachedTradeId = nil
    }
    
    // MARK: - Computed Properties
    
    var isRecent: Bool {
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        return createdAt > oneHourAgo
    }
    
    var timeAgoString: String {
        let interval = Date().timeIntervalSince(createdAt)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(createdAt)
    }
    
    var canEdit: Bool {
        // User can edit posts within 15 minutes of creation
        let fifteenMinutesAgo = Calendar.current.date(byAdding: .minute, value: -15, to: Date()) ?? Date()
        return createdAt > fifteenMinutesAgo
    }
    
    var shareableText: String {
        var text = content
        if !hashtags.isEmpty {
            text += "\n\n" + hashtags.map { "#\($0)" }.joined(separator: " ")
        }
        text += "\n\nShared via ArkadTrader"
        return text
    }
    
    // MARK: - Firebase Integration
    
    func toFirestore() -> [String: Any] {
        return [
            "content": content,
            "imageURL": imageURL as Any,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "authorProfileImageURL": authorProfileImageURL as Any,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": Timestamp(date: createdAt),
            "isPremiumContent": isPremiumContent,
            "postType": postType.rawValue,
            "communityId": communityId as Any,
            "visibility": visibility.rawValue,
            "hashtags": hashtags,
            "mentionedUsers": mentionedUsers,
            "attachedTradeId": attachedTradeId as Any
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> Post {
        guard let content = data["content"] as? String,
              let authorId = data["authorId"] as? String,
              let authorUsername = data["authorUsername"] as? String,
              let likesCount = data["likesCount"] as? Int,
              let commentsCount = data["commentsCount"] as? Int,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let isPremiumContent = data["isPremiumContent"] as? Bool,
              let postTypeString = data["postType"] as? String,
              let postType = PostType(rawValue: postTypeString),
              let visibilityString = data["visibility"] as? String,
              let visibility = PostVisibility(rawValue: visibilityString) else {
            throw FirestoreError.invalidData
        }
        
        var post = Post(content: content, authorId: authorId, authorUsername: authorUsername)
        post.id = UUID(uuidString: id) ?? UUID()
        post.imageURL = data["imageURL"] as? String
        post.authorProfileImageURL = data["authorProfileImageURL"] as? String
        post.likesCount = likesCount
        post.commentsCount = commentsCount
        post.createdAt = createdAtTimestamp.dateValue()
        post.isPremiumContent = isPremiumContent
        post.postType = postType
        post.communityId = data["communityId"] as? String
        post.visibility = visibility
        post.hashtags = data["hashtags"] as? [String] ?? []
        post.mentionedUsers = data["mentionedUsers"] as? [String] ?? []
        post.attachedTradeId = data["attachedTradeId"] as? String
        
        return post
    }
    
    // MARK: - Helper Methods
    
    func extractHashtags(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.compactMap { word in
            if word.hasPrefix("#") && word.count > 1 {
                let hashtag = String(word.dropFirst()).lowercased()
                return hashtag.filter { $0.isLetter || $0.isNumber || $0 == "_" }
            }
            return nil
        }.filter { !$0.isEmpty }
    }
    
    func extractMentions(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.compactMap { word in
            if word.hasPrefix("@") && word.count > 1 {
                let mention = String(word.dropFirst()).lowercased()
                return mention.filter { $0.isLetter || $0.isNumber || $0 == "_" }
            }
            return nil
        }.filter { !$0.isEmpty }
    }
    
    mutating func processContentForSocialFeatures() {
        self.hashtags = extractHashtags(from: content)
        self.mentionedUsers = extractMentions(from: content)
    }
}

enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case image = "image"
    case tradeResult = "trade_result"
    case marketAnalysis = "market_analysis"
    case poll = "poll"
    case news = "news"
    case educational = "educational"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .tradeResult: return "Trade Result"
        case .marketAnalysis: return "Market Analysis"
        case .poll: return "Poll"
        case .news: return "News"
        case .educational: return "Educational"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .image: return "photo"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar.doc.horizontal"
        case .poll: return "list.bullet.clipboard"
        case .news: return "newspaper"
        case .educational: return "graduationcap"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .image: return "purple"
        case .tradeResult: return "green"
        case .marketAnalysis: return "orange"
        case .poll: return "indigo"
        case .news: return "red"
        case .educational: return "teal"
        }
    }
}

enum PostVisibility: String, CaseIterable, Codable {
    case public = "public"
    case community = "community"
    case followers = "followers"
    case private = "private"
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .community: return "Community Only"
        case .followers: return "Followers Only"
        case .private: return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .community: return "person.3"
        case .followers: return "person.2"
        case .private: return "lock"
        }
    }
    
    var description: String {
        switch self {
        case .public: return "Anyone can see this post"
        case .community: return "Only community members can see this post"
        case .followers: return "Only your followers can see this post"
        case .private: return "Only you can see this post"
        }
    }
}

// MARK: - Post Extensions for Additional Functionality

extension Post {
    // Check if user can interact with post based on visibility
    func canUserView(userId: String, userFollowing: [String], userCommunities: [String]) -> Bool {
        switch visibility {
        case .public:
            return true
        case .community:
            guard let communityId = communityId else { return false }
            return userCommunities.contains(communityId)
        case .followers:
            return authorId == userId || userFollowing.contains(authorId)
        case .private:
            return authorId == userId
        }
    }
    
    // Generate content preview for notifications
    var contentPreview: String {
        let maxLength = 100
        if content.count <= maxLength {
            return content
        } else {
            return String(content.prefix(maxLength)) + "..."
        }
    }
    
    // Check if post contains sensitive content (basic implementation)
    var containsSensitiveContent: Bool {
        let sensitiveKeywords = ["violence", "hate", "spam", "scam"]
        let lowercaseContent = content.lowercased()
        return sensitiveKeywords.contains { lowercaseContent.contains($0) }
    }
    
    // Get engagement rate (likes + comments / views - simplified)
    func getEngagementRate(views: Int) -> Double {
        guard views > 0 else { return 0 }
        let totalEngagement = likesCount + commentsCount
        return Double(totalEngagement) / Double(views) * 100
    }
}

// MARK: - Post Sorting and Filtering

extension Array where Element == Post {
    func sortedByRecent() -> [Post] {
        return self.sorted { $0.createdAt > $1.createdAt }
    }
    
    func sortedByPopularity() -> [Post] {
        return self.sorted { ($0.likesCount + $0.commentsCount) > ($1.likesCount + $1.commentsCount) }
    }
    
    func filteredByType(_ type: PostType) -> [Post] {
        return self.filter { $0.postType == type }
    }
    
    func filteredByVisibility(_ visibility: PostVisibility) -> [Post] {
        return self.filter { $0.visibility == visibility }
    }
    
    func filteredByHashtag(_ hashtag: String) -> [Post] {
        return self.filter { $0.hashtags.contains(hashtag.lowercased()) }
    }
    
    func filteredByAuthor(_ authorId: String) -> [Post] {
        return self.filter { $0.authorId == authorId }
    }
    
    func filteredByCommunity(_ communityId: String) -> [Post] {
        return self.filter { $0.communityId == communityId }
    }
    
    func filteredByDateRange(from startDate: Date, to endDate: Date) -> [Post] {
        return self.filter { post in
            post.createdAt >= startDate && post.createdAt <= endDate
        }
    }
}
