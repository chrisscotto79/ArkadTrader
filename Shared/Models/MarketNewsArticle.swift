//
//  MarketNewsArticle.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/13/25.
//


// File: Shared/Models/MarketNewsArticle.swift
// Create this new file in your Shared/Models folder

import Foundation
import FirebaseFirestore

struct MarketNewsArticle: Identifiable, Codable {
    let id: String
    let title: String
    let author: String?
    let publishedUtc: String
    let articleUrl: String
    let description: String?
    let keywords: [String]
    let imageUrl: String?
    let cachedAt: Date
    let source: String?
    let category: String?
    
    var publishedDate: Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFormatter.date(from: publishedUtc)
    }
    
    var timeAgo: String {
        guard let date = publishedDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var hasImage: Bool {
        return imageUrl != nil && !imageUrl!.isEmpty
    }
    
    init(id: String, title: String, author: String?, publishedUtc: String, articleUrl: String, description: String?, keywords: [String], imageUrl: String?, cachedAt: Date, source: String?, category: String?) {
        self.id = id
        self.title = title
        self.author = author
        self.publishedUtc = publishedUtc
        self.articleUrl = articleUrl
        self.description = description
        self.keywords = keywords
        self.imageUrl = imageUrl
        self.cachedAt = cachedAt
        self.source = source
        self.category = category
    }
    
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "publishedUtc": publishedUtc,
            "articleUrl": articleUrl,
            "keywords": keywords,
            "cachedAt": Timestamp(date: cachedAt)
        ]
        
        if let author = author {
            data["author"] = author
        }
        
        if let description = description {
            data["description"] = description
        }
        
        if let imageUrl = imageUrl {
            data["imageUrl"] = imageUrl
        }
        
        if let source = source {
            data["source"] = source
        }
        
        if let category = category {
            data["category"] = category
        }
        
        return data
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> MarketNewsArticle {
        guard let title = data["title"] as? String,
              let publishedUtc = data["publishedUtc"] as? String,
              let articleUrl = data["articleUrl"] as? String,
              let keywords = data["keywords"] as? [String],
              let cachedAtTimestamp = data["cachedAt"] as? Timestamp else {
            throw NSError(domain: "MarketNewsArticleDecoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid market news article data"])
        }
        
        return MarketNewsArticle(
            id: id,
            title: title,
            author: data["author"] as? String,
            publishedUtc: publishedUtc,
            articleUrl: articleUrl,
            description: data["description"] as? String,
            keywords: keywords,
            imageUrl: data["imageUrl"] as? String,
            cachedAt: cachedAtTimestamp.dateValue(),
            source: data["source"] as? String,
            category: data["category"] as? String
        )
    }
    
    static func fromNewsItem(_ item: NewsItem) -> MarketNewsArticle? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        let publishedDate = Date(timeIntervalSince1970: TimeInterval(item.datetime))
        let publishedUtc = formatter.string(from: publishedDate)
        
        let keywords = item.related?.components(separatedBy: ",") ?? []
        
        return MarketNewsArticle(
            id: String(item.id),
            title: item.headline,
            author: nil,
            publishedUtc: publishedUtc,
            articleUrl: item.url,
            description: item.summary,
            keywords: keywords,
            imageUrl: item.image.isEmpty ? nil : item.image,
            cachedAt: Date(),
            source: item.source,
            category: item.category
        )
    }
}

// Supporting structure for API response
struct NewsItem: Codable {
    let id: Int
    let headline: String
    let summary: String
    let url: String
    let image: String
    let datetime: Int
    let source: String
    let category: String
    let related: String?
}