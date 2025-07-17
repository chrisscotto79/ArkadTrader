// File: Shared/Models/Post.swift
// Simplified Post Model

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
    var hashtags: [String] = []
    var tickerSymbols: [String] = []
    var sharesCount: Int = 0
    var authorProfileImageUrl: String?

    // Initializer
    init(content: String, authorId: String, authorUsername: String) {
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.likesCount = 0
        self.commentsCount = 0
        self.sharesCount = 0  // Add this
        self.createdAt = Date()
        self.postType = .text
        self.hashtags = []  // Add this
        self.tickerSymbols = []  // Add this
        self.authorProfileImageUrl = nil  // Add this
    }

    // Firebase conversion
    func toFirestore() -> [String: Any] {
        return [
            "content": content,
            "authorId": authorId,
            "authorUsername": authorUsername,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": Timestamp(date: createdAt),
            "postType": postType.rawValue
        ]
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

        return post
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
}
