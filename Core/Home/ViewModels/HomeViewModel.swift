// File: Core/Home/ViewModels/HomeViewModel.swift
// The Home feed and News tab, plus MarketNewsArticle.

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage

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
    
    // MARK: - Publish date
    // publishedUtc is an ISO 8601 UTC string (e.g. "2026-11-22T14:05:00Z"), which also
    // sorts correctly as a string in Firestore. Finnhub gives unix seconds.
    
    static func utcString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
    
    /// Parses publishedUtc with or without fractional seconds.
    static func date(fromUTCString string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
    
    var publishedDate: Date? {
        MarketNewsArticle.date(fromUTCString: publishedUtc)
    }
    
    /// "Just now", "5m ago", "2h ago", "3d ago", then a short date.
    var relativePublishedText: String {
        guard let date = publishedDate else { return "" }
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60:
            return "Just now"
        case ..<3600:
            return "\(Int(seconds / 60))m ago"
        case ..<86_400:
            return "\(Int(seconds / 3600))h ago"
        case ..<(7 * 86_400):
            return "\(Int(seconds / 86_400))d ago"
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    // Firebase conversion methods
    func toFirestore() -> [String: Any] {
        return [
            "title": title,
            "author": author as Any,
            "publishedUtc": publishedUtc,
            "articleUrl": articleUrl,
            "description": description as Any,
            "keywords": keywords,
            "imageUrl": imageUrl as Any,
            "cachedAt": Timestamp(date: cachedAt),
            "source": source as Any,
            "category": category as Any
        ]
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
}

/// The Home tab's For You feed (newest posts, paged) and the News tab. Likes, bookmarks,
/// counts, deletes and reports live in PostStore, shared by every screen.
@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var marketNews: [MarketNewsArticle] = []
    @Published var isLoading = false
    @Published var isLoadingNews = false
    @Published var isRefreshing = false
    /// The feed couldn't load (shown in place of the feed, or above it when posts are showing).
    @Published var loadError: String?
    /// News errors, shown as an alert.
    @Published var errorMessage = ""
    @Published var showError = false

    // Paging
    @Published var hasMorePosts = false
    @Published var isLoadingMore = false
    @Published var loadMoreError: String?

    private let authService = FirebaseAuthService.shared
    private let postStore = PostStore.shared
    private let pageSize = 30
    private var cursor: DocumentSnapshot?
    /// Bumped on every first-page load so a late "load more" for an older list is dropped.
    private var generation = 0

    // Finnhub API configuration
    private var finnhubApiKey: String { AppConfig.finnhubAPIKey }
    private let finnhubBaseUrl = "https://finnhub.io/api/v1"

    // MARK: - Feed

    /// The first page of the feed. On failure the posts already showing stay.
    func loadPosts() async {
        generation += 1
        let thisGeneration = generation
        isLoading = true
        defer { if thisGeneration == generation { isLoading = false } }

        async let interactions: Void = postStore.loadIfNeeded()
        async let blocks: Void = BlockStore.shared.loadIfNeeded()
        do {
            let page = try await FirebaseServices.shared.getFeedPage(limit: pageSize, after: nil)
            _ = await (interactions, blocks)
            guard thisGeneration == generation else { return }
            posts = page.posts
            postStore.absorb(page.posts)
            cursor = page.cursor
            hasMorePosts = page.cursor != nil
            loadError = nil
            loadMoreError = nil
        } catch {
            _ = await (interactions, blocks)
            guard thisGeneration == generation else { return }
            loadError = TickerFeedError.friendlyMessage(for: error)
        }
    }

    func refreshPosts() async {
        isRefreshing = true
        await loadPosts()
        isRefreshing = false
    }

    /// The next page, after the last post loaded.
    func loadMorePosts() async {
        guard hasMorePosts, !isLoadingMore, let cursor else { return }
        let thisGeneration = generation
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }

        do {
            let page = try await FirebaseServices.shared.getFeedPage(limit: pageSize, after: cursor)
            guard thisGeneration == generation else { return }
            let shown = Set(posts.map(\.id))
            let fresh = page.posts.filter { !shown.contains($0.id) }
            posts.append(contentsOf: fresh)
            postStore.absorb(fresh)
            self.cursor = page.cursor
            hasMorePosts = page.cursor != nil
        } catch {
            guard thisGeneration == generation else { return }
            loadMoreError = TickerFeedError.friendlyMessage(for: error)
        }
    }

    // MARK: - New post

    /// Saves the composer's post. Throws so the composer can stay open and show the error.
    func createPost(_ draft: PostDraft) async throws {
        try await createPost(content: draft.content, tickers: draft.tickers, images: draft.images,
                             postType: draft.postType, trade: draft.trade, sentiment: draft.sentiment)
    }

    /// Without a postType, it's guessed from the text (for callers that don't have the composer's choice).
    /// A trade-result post needs `trade`, one of the author's own closed trades: its numbers and proof
    /// label are copied into `tradeSnapshot` (no typed-in P&L). Without one it's posted as a text post.
    func createPost(content: String, tickers: [String] = [], images: [UIImage] = [],
                    postType chosenType: PostType? = nil, trade: Trade? = nil,
                    sentiment: PostSentiment? = nil) async throws {
        guard let currentUser = authService.currentUser else {
            throw NSError(domain: "Post", code: 0, userInfo: [NSLocalizedDescriptionKey: "Sign in to post."])
        }
        let userId = currentUser.id

        var postType = chosenType ?? determinePostType(from: content)
        let snapshot = trade.flatMap { $0.userId == userId ? TradeSnapshot(trade: $0) : nil }
        if postType == .tradeResult && snapshot == nil {
            postType = .text
        }

        // Photos stay off until Cloud Storage is available (AppConfig.mediaUploadsEnabled)
        var imageUrls: [String] = []
        if AppConfig.mediaUploadsEnabled && !images.isEmpty {
            let imageBatchId = UUID().uuidString
            for (index, image) in images.enumerated() {
                if let imageUrl = try? await uploadImage(image, postId: imageBatchId, imageIndex: index) {
                    imageUrls.append(imageUrl)
                }
            }
        }

        // The stored username: the rules check it against users/{uid}.username
        var newPost = Post(
            content: content,
            authorId: userId,
            authorUsername: currentUser.username,
            postType: postType,
            tickers: tickers,
            imageUrls: imageUrls
        )
        newPost.authorFullName = currentUser.fullName
        newPost.authorAvatarURL = currentUser.profileImageUrl
        newPost.sentiment = newPost.tickers.isEmpty ? nil : sentiment

        // Trade result: the chosen closed trade. FirebaseServices.createPost copies the snapshot
        // from the trade document so it matches what the rules check.
        if postType == .tradeResult, let trade, let snapshot {
            newPost.tradeId = trade.id
            newPost.tradeSnapshot = snapshot
            let symbol = Cashtag.normalize(snapshot.ticker)
            if Cashtag.isValid(symbol), !newPost.tickers.contains(symbol) {
                newPost.tickers = Cashtag.cleaned([symbol] + newPost.tickers)
            }
        }

        try await FirebaseServices.shared.createPost(newPost)
        posts.insert(newPost, at: 0)
    }

    private func uploadImage(_ image: UIImage, postId: String, imageIndex: Int) async throws -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        let storageRef = Storage.storage().reference().child("post_images/\(postId)_\(imageIndex).jpg")
        _ = try await storageRef.putDataAsync(imageData)
        return try await storageRef.downloadURL().absoluteString
    }

    // MARK: - Helper Methods

    private func determinePostType(from content: String) -> PostType {
        let lowercaseContent = content.lowercased()

        if lowercaseContent.contains("#trade") ||
           lowercaseContent.contains("profit") ||
           lowercaseContent.contains("loss") ||
           lowercaseContent.contains("position") ||
           lowercaseContent.contains("buy") ||
           lowercaseContent.contains("sell") {
            return .tradeResult
        } else if lowercaseContent.contains("#analysis") ||
                  lowercaseContent.contains("market") ||
                  lowercaseContent.contains("bullish") ||
                  lowercaseContent.contains("bearish") ||
                  lowercaseContent.contains("technical") ||
                  lowercaseContent.contains("chart") {
            return .marketAnalysis
        } else {
            return .text
        }
    }

    // MARK: - News

    /// The newest few articles that have a picture, shown as large cards.
    /// (Finnhub returns general news newest-first; there is no popularity signal.)
    func getTopStories() -> [MarketNewsArticle] {
        let articlesWithImages = marketNews.filter { article in
            if let imageUrl = article.imageUrl { return !imageUrl.isEmpty }
            return false
        }
        return Array(articlesWithImages.prefix(5))
    }

    /// Every other article, newest first.
    func getRegularNews() -> [MarketNewsArticle] {
        let topIds = Set(getTopStories().map { $0.id })
        return marketNews.filter { !topIds.contains($0.id) }
    }

    // MARK: - Market News Management
    func loadMarketNews() async {
        isLoadingNews = true
        
        do {
            let articles = try await fetchMarketNews()
            marketNews = articles
        } catch {
            errorMessage = "Couldn't load the news. Pull to refresh or try again."
            showError = true
        }
        
        isLoadingNews = false
    }
    
    fileprivate func fetchMarketNews() async throws -> [MarketNewsArticle] {
        guard !finnhubApiKey.isEmpty else { return [] }
        let urlString = "\(finnhubBaseUrl)/news?category=general&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        // Same Finnhub key and per-minute budget as stock quotes (QuoteClient)
        guard await QuoteClient.shared.reserveCall() else { return [] }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        if (response as? HTTPURLResponse)?.statusCode == 429 {
            await QuoteClient.shared.reportRateLimited()
            return []
        }
        let newsItems = try JSONDecoder().decode([NewsItem].self, from: data)
        
        return newsItems
            .sorted { $0.datetime > $1.datetime }
            .prefix(50)
            .compactMap { item in
                MarketNewsArticle.fromNewsItem(item)
            }
    }
}

// MARK: - Finnhub news
fileprivate struct NewsItem: Codable {
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

extension MarketNewsArticle {
    fileprivate static func fromNewsItem(_ item: NewsItem) -> MarketNewsArticle? {
        // Finnhub's datetime is unix seconds (UTC)
        let publishedDate = Date(timeIntervalSince1970: TimeInterval(item.datetime))
        let publishedUtc = MarketNewsArticle.utcString(from: publishedDate)
        
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
