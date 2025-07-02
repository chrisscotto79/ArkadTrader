// Core/Home/Views/MarketNewsFeedView.swift
// ArkadTrader

import SwiftUI

struct MarketNewsFeedView: View {
    @StateObject private var newsFetcher = PolygonNewsFetcher()
    @State private var timer: Timer?
    @State private var selectedNewsItem: PolygonNewsItem?
    @State private var showingShareSheet = false
    @State private var shareItem: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Featured News Section
                if !newsFetcher.featuredNews.isEmpty {
                    FeaturedNewsSection(
                        featuredNews: newsFetcher.featuredNews,
                        onTap: { item in
                            selectedNewsItem = item
                        },
                        onShare: { item in
                            shareNews(item)
                        }
                    )
                }
                
                // Error State
                if newsFetcher.hasError {
                    ErrorView(
                        message: newsFetcher.errorMessage,
                        retryAction: {
                            newsFetcher.retry()
                        }
                    )
                    .padding()
                }
                
                // Section Header
                if !newsFetcher.newsItems.isEmpty {
                    HStack {
                        Text("Latest News")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(newsFetcher.newsItems.count) articles")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                }
                
                // News Items
                ForEach(newsFetcher.regularNews) { item in
                    LiveNewsCard(news: item) {
                        selectedNewsItem = item
                    } onShare: {
                        shareNews(item)
                    }
                }
                
                // Loading State
                if newsFetcher.isLoading && newsFetcher.newsItems.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading market news...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
                
                // Load More Button
                if !newsFetcher.newsItems.isEmpty && newsFetcher.hasMorePages {
                    Button(action: {
                        newsFetcher.loadMore()
                    }) {
                        if newsFetcher.isLoadingMore {
                            ProgressView()
                                .padding()
                        } else {
                            Text("Load More")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                                .padding()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .onAppear {
            newsFetcher.fetchNews()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            newsFetcher.fetchNews()
            startAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            stopAutoRefresh()
        }
        .refreshable {
            await newsFetcher.refreshNews()
        }
        .sheet(item: $selectedNewsItem) { item in
            NewsDetailSheet(newsItem: item)
        }
        .sheet(isPresented: $showingShareSheet) {
            NewsShareSheet(items: [shareItem])
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            newsFetcher.fetchNews(isAutoRefresh: true)
        }
    }

    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    private func shareNews(_ item: PolygonNewsItem) {
        shareItem = """
        📰 \(item.headline)
        
        \(item.summary ?? "")
        
        Tickers: \(item.symbols.joined(separator: ", "))
        
        Read more: \(item.url ?? "")
        
        Shared via ArkadTrader
        """
        showingShareSheet = true
    }
}

// MARK: - Featured News Section
struct FeaturedNewsSection: View {
    let featuredNews: [PolygonNewsItem]
    let onTap: (PolygonNewsItem) -> Void
    let onShare: (PolygonNewsItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.arkadGold)
                    .font(.caption)
                
                Text("Featured Stories")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredNews) { item in
                        FeaturedNewsCard(
                            news: item,
                            onTap: { onTap(item) },
                            onShare: { onShare(item) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Featured News Card
struct FeaturedNewsCard: View {
    let news: PolygonNewsItem
    let onTap: () -> Void
    let onShare: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Background image if available
                if let imageURL = news.imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.arkadBlack,
                                        Color.arkadBlack.opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 280, height: 180)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else {
                    // Fallback gradient if no image
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.arkadBlack,
                            Color.arkadBlack.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 280, height: 180)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Featured Badge
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("TRENDING")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                        
                        Spacer()
                        
                        Button(action: onShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(news.headline)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Bottom Info
                        HStack {
                            HStack(spacing: 4) {
                                ForEach(news.symbols.prefix(3), id: \.self) { symbol in
                                    Text(symbol)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.arkadBlack)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.arkadGold)
                                        .cornerRadius(4)
                                }
                                
                                if news.symbols.count > 3 {
                                    Text("+\(news.symbols.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            Spacer()
                            
                            Text(news.formattedDate)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
            }
            .frame(width: 280, height: 180)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Enhanced News Fetcher
class PolygonNewsFetcher: ObservableObject {
    @Published var newsItems: [PolygonNewsItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var hasMorePages = true
    
    // Computed properties for featured and regular news
    var featuredNews: [PolygonNewsItem] {
        // Featured news criteria:
        // 1. Has multiple tickers (>= 3)
        // 2. Published within last 2 hours
        // 3. Take top 5
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        
        return newsItems
            .filter { item in
                item.tickers.count >= 3 && item.createdAt > twoHoursAgo
            }
            .prefix(5)
            .map { $0 }
    }
    
    var regularNews: [PolygonNewsItem] {
        // Filter out featured items from regular news
        let featuredIds = Set(featuredNews.map { $0.id })
        return newsItems.filter { !featuredIds.contains($0.id) }
    }
    
    private var currentPage = 1
    private let pageSize = 20
    private var lastFetchTime: Date?
    private let minimumRefreshInterval: TimeInterval = 60 // 1 minute
    private var newsCache = Set<String>() // Track seen news IDs
    
    // TODO: Move to environment configuration
    private let apiKey = "x3gVFWOZqHWtmYIz770auaj576WSF2Fh"
    private let baseURL = "https://api.polygon.io/v2/reference/news"
    
    func fetchNews(isAutoRefresh: Bool = false) {
        // Prevent too frequent refreshes
        if isAutoRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < minimumRefreshInterval {
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        hasError = false
        
        Task {
            await performFetch(page: 1, append: false)
        }
    }
    
    func refreshNews() async {
        currentPage = 1
        hasMorePages = true
        await performFetch(page: 1, append: false)
    }
    
    func loadMore() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            await performFetch(page: currentPage, append: true)
        }
    }
    
    func retry() {
        hasError = false
        fetchNews()
    }
    
    @MainActor
    private func performFetch(page: Int, append: Bool) async {
        do {
            let urlString = "\(baseURL)?limit=\(pageSize)&order=desc&sort=published_utc&apiKey=\(apiKey)"
            guard let url = URL(string: urlString) else {
                throw NetworkError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                throw NetworkError.rateLimited
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            let decoded = try JSONDecoder().decode(PolygonNewsResponse.self, from: data)
            
            var newItems = decoded.results ?? []
            
            // Filter out duplicates
            newItems = newItems.filter { item in
                !newsCache.contains(item.id)
            }
            
            // Add to cache
            newItems.forEach { newsCache.insert($0.id) }
            
            if append {
                newsItems.append(contentsOf: newItems)
            } else {
                newsItems = newItems
            }
            
            hasMorePages = newItems.count == pageSize
            lastFetchTime = Date()
            isLoading = false
            isLoadingMore = false
            
        } catch {
            handleError(error)
        }
    }
    
    @MainActor
    private func handleError(_ error: Error) {
        isLoading = false
        isLoadingMore = false
        hasError = true
        
        switch error {
        case NetworkError.rateLimited:
            errorMessage = "Too many requests. Please try again later."
        case NetworkError.noInternet:
            errorMessage = "No internet connection. Please check your network."
        case NetworkError.httpError(let statusCode):
            errorMessage = "Server error (Code: \(statusCode)). Please try again."
        default:
            errorMessage = "Unable to load news. Please try again."
        }
        
        print("❌ News fetch error: \(error)")
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noInternet
    case rateLimited
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidResponse:
            return "Invalid server response"
        case .noInternet:
            return "No internet connection"
        case .rateLimited:
            return "API rate limit exceeded"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

// MARK: - Enhanced News Model
struct PolygonNewsResponse: Decodable {
    let results: [PolygonNewsItem]?
    let status: String?
    let next_url: String?
}

struct PolygonNewsItem: Identifiable, Decodable {
    let id: String
    let title: String
    let description: String?
    let published_utc: String
    let article_url: String?
    let tickers: [String]
    let image_url: String?
    let publisher: Publisher?

    var headline: String { title }
    var summary: String? { description }
    var url: String? { article_url }
    var imageURL: String? { image_url }
    var symbols: [String] { Array(tickers.prefix(6)) }

    var createdAt: Date {
        ISO8601DateFormatter().date(from: published_utc) ?? Date()
    }

    var source: String {
        publisher?.name ?? "Market News"
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    struct Publisher: Decodable {
        let name: String
        let homepage_url: String?
        let logo_url: String?
    }
}

// MARK: - Enhanced News Card
struct LiveNewsCard: View {
    let news: PolygonNewsItem
    let onTap: () -> Void
    let onShare: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // News image thumbnail if available
                if let imageURL = news.imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .clipped()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(news.source)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.arkadGold)
                                
                                Text("•")
                                    .foregroundColor(.gray)
                                
                                Text(news.formattedDate)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            PulsingLiveIndicator()
                            
                            Button(action: onShare) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Content
                    Text(news.headline)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(news.imageURL != nil ? 2 : 3)
                    
                    if news.imageURL == nil, let summary = news.summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Tickers
                    if !news.symbols.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(news.symbols, id: \.self) { symbol in
                                    TickerChip(symbol: symbol)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Supporting Views
struct PulsingLiveIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(Color.red, lineWidth: 1)
                        .scaleEffect(isAnimating ? 2.5 : 1)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                )
            
            Text("LIVE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct TickerChip: View {
    let symbol: String
    
    var body: some View {
        NavigationLink(destination: EmptyView()) { // TODO: Link to ticker detail
            Text(symbol)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.arkadGold.opacity(0.15))
                .foregroundColor(.arkadGold)
                .cornerRadius(6)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.arkadGold)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NewsDetailSheet: View {
    let newsItem: PolygonNewsItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Display image if available
                    if let imageURL = newsItem.imageURL, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .cornerRadius(12)
                    }
                    
                    Text(newsItem.headline)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(newsItem.source)
                            .font(.subheadline)
                            .foregroundColor(.arkadGold)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(newsItem.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if let summary = newsItem.summary {
                        Text(summary)
                            .font(.body)
                    }
                    
                    // Display tickers
                    if !newsItem.symbols.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Tickers")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(newsItem.symbols, id: \.self) { symbol in
                                    Text(symbol)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.arkadGold.opacity(0.15))
                                        .foregroundColor(.arkadGold)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    if let urlString = newsItem.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack {
                                Text("Read Full Article")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.arkadGold)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("News Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - News Share Sheet (Renamed to avoid conflict)
struct NewsShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Flow Layout for Tickers
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.frames[index].minX + bounds.minX,
                                     y: result.frames[index].minY + bounds.minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    MarketNewsFeedView()
}
