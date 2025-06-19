//
//  Post.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Shared/Models/Post.swift

import Foundation

struct Post: Identifiable, Codable {
    let id: UUID
    var content: String
    var imageURL: String?
    var authorId: UUID
    var authorUsername: String
    var authorProfileImageURL: String?
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var isPremiumContent: Bool
    var postType: PostType
    
    init(content: String, authorId: UUID, authorUsername: String) {
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
    }
}

enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case image = "image"
    case tradeResult = "trade_result"
    case marketAnalysis = "market_analysis"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .tradeResult: return "Trade Result"
        case .marketAnalysis: return "Market Analysis"
        }
    }
}
