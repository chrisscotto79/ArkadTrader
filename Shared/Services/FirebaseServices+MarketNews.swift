// File: Shared/Services/FirebaseServices+MarketNews.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Market News Methods
    
    func cacheMarketNews(articles: [MarketNewsArticle]) async throws {
        let batch = db.batch()
        
        for article in articles {
            let ref = db.collection("marketNews").document(article.id)
            batch.setData(article.toFirestore(), forDocument: ref)
        }
        
        try await batch.commit()
    }
    
    func getCachedMarketNews() async throws -> [MarketNewsArticle] {
        let snapshot = try await db.collection("marketNews")
            .order(by: "publishedUtc", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func clearOldMarketNews() async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("marketNews")
            .whereField("cachedAt", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()
        
        let batch = db.batch()
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
    
    func searchMarketNews(query: String) async throws -> [MarketNewsArticle] {
        let snapshot = try await db.collection("marketNews")
            .order(by: "publishedUtc", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        let articles = snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        return articles.filter { article in
            article.title.lowercased().contains(query.lowercased()) ||
            (article.description ?? "").lowercased().contains(query.lowercased()) ||
            article.keywords.contains { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    func getMarketNewsAnalytics() async throws -> NewsAnalytics {
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("marketNews")
            .whereField("cachedAt", isGreaterThan: Timestamp(date: oneWeekAgo))
            .getDocuments()
        
        let articles = snapshot.documents.compactMap { document in
            try? MarketNewsArticle.fromFirestore(data: document.data(), id: document.documentID)
        }
        
        // Analyze keywords
        var keywordCounts: [String: Int] = [:]
        for article in articles {
            for keyword in article.keywords {
                keywordCounts[keyword, default: 0] += 1
            }
        }
        
        let topKeywords = keywordCounts.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        // Analyze sources
        var sourceCounts: [String: Int] = [:]
        for article in articles {
            if let source = article.source {
                sourceCounts[source, default: 0] += 1
            }
        }
        
        return NewsAnalytics(
            totalArticles: articles.count,
            topKeywords: topKeywords,
            sourceCounts: sourceCounts,
            lastUpdated: Date()
        )
    }
}
