// Enhanced Post Model with Image Support
// Replace your existing Post.swift file with this enhanced version

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
    
    // NEW: Image support
    var imageUrls: [String]?  // Support for multiple images
    var hasImages: Bool { return !(imageUrls?.isEmpty ?? true) }
    
    // NEW: Enhanced metadata
    var updatedAt: Date?
    var isEdited: Bool { return updatedAt != nil && updatedAt != createdAt }
    
    // NEW: Content moderation
    var isReported: Bool = false
    var reportCount: Int = 0

    // Initializer for text-only posts
    init(content: String, authorId: String, authorUsername: String) {
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.postType = .text
        self.imageUrls = nil
        self.updatedAt = nil
    }
    
    // Initializer with images
    init(content: String, authorId: String, authorUsername: String, imageUrls: [String]?) {
        self.id = UUID().uuidString
        self.content = content
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.likesCount = 0
        self.commentsCount = 0
        self.createdAt = Date()
        self.postType = .text
        self.imageUrls = imageUrls
        self.updatedAt = nil
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
            "isReported": isReported,
            "reportCount": reportCount
        ]
        
        // Add optional fields
        if let imageUrls = imageUrls, !imageUrls.isEmpty {
            data["imageUrls"] = imageUrls
        }
        
        if let updatedAt = updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
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
        
        // Load optional fields
        post.imageUrls = data["imageUrls"] as? [String]
        
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            post.updatedAt = updatedAtTimestamp.dateValue()
        }
        
        post.isReported = data["isReported"] as? Bool ?? false
        post.reportCount = data["reportCount"] as? Int ?? 0

        return post
    }
    
    // MARK: - Helper Methods
    
    func getFirstImageUrl() -> String? {
        return imageUrls?.first
    }
    
    func hasMultipleImages() -> Bool {
        return (imageUrls?.count ?? 0) > 1
    }
    
    func getImageCount() -> Int {
        return imageUrls?.count ?? 0
    }
    
    // Create a copy with updated content (for editing)
    func updatingContent(_ newContent: String) -> Post {
        var updatedPost = self
        updatedPost.content = newContent
        updatedPost.updatedAt = Date()
        return updatedPost
    }
    
    // Create a copy with added images
    func addingImages(_ newImageUrls: [String]) -> Post {
        var updatedPost = self
        if updatedPost.imageUrls == nil {
            updatedPost.imageUrls = newImageUrls
        } else {
            updatedPost.imageUrls?.append(contentsOf: newImageUrls)
        }
        updatedPost.updatedAt = Date()
        return updatedPost
    }
}

enum PostType: String, CaseIterable, Codable {
    case text = "text"
    case tradeResult = "trade_result"
    case marketAnalysis = "market_analysis"
    case image = "image"  // NEW: Image post type

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .tradeResult: return "Trade Result"
        case .marketAnalysis: return "Market Analysis"
        case .image: return "Photo"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .tradeResult: return "chart.line.uptrend.xyaxis"
        case .marketAnalysis: return "chart.bar.doc.horizontal"
        case .image: return "photo"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .tradeResult: return "green"
        case .marketAnalysis: return "purple"
        case .image: return "orange"
        }
    }
    
    var placeholder: String {
        switch self {
        case .text: return "What's on your mind?"
        case .tradeResult: return "Share your trade results and insights..."
        case .marketAnalysis: return "Share your market analysis and predictions..."
        case .image: return "Share a photo with caption..."
        }
    }
}
