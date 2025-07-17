//
//  MarketNewsTabView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/17/25.
//


// File: Core/Home/Views/Components/MarketNewsComponents.swift
// Market news components with ticker interactions and article viewing

import SwiftUI
import SafariServices

// MARK: - Market News Tab View
struct MarketNewsTabView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var selectedArticle: MarketNewsArticle?
    @State private var showingArticleDetail = false
    @State private var showingWebView = false
    @State private var selectedURL: URL?
    @State private var scrollToTopId = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // Market overview header
            marketOverviewSection
            
            // Main news content
            newsContent
        }
        .refreshable {
            await homeViewModel.refreshMarketNews()
        }
        .sheet(isPresented: $showingArticleDetail) {
            if let article = selectedArticle {
                ArticleDetailView(article: article)
                    .environmentObject(homeViewModel)
            }
        }
        .sheet(isPresented: $showingWebView) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToTop"))) { _ in
            withAnimation {
                scrollToTopId = UUID()
            }
        }
    }
    
    // MARK: - Market Overview Section
    private var marketOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Market Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            
            // Market indices
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Mock market data - replace with real data
                    MarketIndexCard(
                        name: "S&P 500",
                        symbol: "SPX",
                        value: "4,567.89",
                        change: "+23.45",
                        changePercent: "+0.52%",
                        isPositive: true
                    ) {
                        homeViewModel.applyTickerFilter("SPX")
                    }
                    
                    MarketIndexCard(
                        name: "NASDAQ",
                        symbol: "IXIC",
                        value: "14,234.56",
                        change: "-45.67",
                        changePercent: "-0.32%",
                        isPositive: false
                    ) {
                        homeViewModel.applyTickerFilter("IXIC")
                    }
                    
                    MarketIndexCard(
                        name: "DOW",
                        symbol: "DJI",
                        value: "34,876.23",
                        change: "+156.78",
                        changePercent: "+0.45%",
                        isPositive: true
                    ) {
                        homeViewModel.applyTickerFilter("DJI")
                    }
                    
                    MarketIndexCard(
                        name: "VIX",
                        symbol: "VIX",
                        value: "18.45",
                        change: "-1.23",
                        changePercent: "-6.26%",
                        isPositive: false
                    ) {
                        homeViewModel.applyTickerFilter("VIX")
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - News Content
    private var newsContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Scroll to top anchor
                    Color.clear
                        .frame(height: 1)
                        .id(scrollToTopId)
                    
                    if homeViewModel.isLoadingNews && homeViewModel.marketNews.isEmpty {
                        LoadingView(message: "Loading market news...")
                            .padding(.top, 50)
                    } else if homeViewModel.marketNews.isEmpty {
                        EmptyNewsView()
                            .padding(.top, 50)
                    } else {
                        // Trending news section
                        if !homeViewModel.getTrendingNews().isEmpty {
                            trendingNewsSection
                        }
                        
                        // All news section
                        allNewsSection
                        
                        // Load more button
                        if homeViewModel.hasMoreNews {
                            LoadMoreButton {
                                Task {
                                    await homeViewModel.loadMoreNews()
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Loading more indicator
                        if homeViewModel.isLoadingMore {
                            LoadingMoreView()
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 100) // Space for tab bar
            }
            .onChange(of: scrollToTopId) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(scrollToTopId, anchor: .top)
                }
            }
        }
    }
    
    // MARK: - Trending News Section
    private var trendingNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trending")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(homeViewModel.getTrendingNews(), id: \.id) { article in
                        TrendingNewsCard(article: article) {
                            handleArticleTap(article)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - All News Section
    private var allNewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Latest News")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            ForEach(homeViewModel.getRegularNews(), id: \.id) { article in
                NewsArticleCard(article: article) {
                    handleArticleTap(article)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleArticleTap(_ article: MarketNewsArticle) {
        selectedArticle = article
        showingArticleDetail = true
    }
}

// MARK: - Market Index Card
struct MarketIndexCard: View {
    let name: String
    let symbol: String
    let value: String
    let change: String
    let changePercent: String
    let isPositive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(symbol)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.arkadGold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.arkadGold.opacity(0.1))
                        .cornerRadius(3)
                }
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundColor(isPositive ? .green : .red)
                    
                    Text(change)
                        .font(.caption)
                        .foregroundColor(isPositive ? .green : .red)
                    
                    Text(changePercent)
                        .font(.caption)
                        .foregroundColor(isPositive ? .green : .red)
                }
            }
            .padding()
            .frame(width: 130)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trending News Card
struct TrendingNewsCard: View {
    let article: MarketNewsArticle
    let onTap: () -> Void
    @State private var imageLoadError = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Article image
                AsyncImage(url: URL(string: article.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.arkadGold.opacity(0.1))
                        .frame(width: 280, height: 140)
                        .overlay(
                            VStack {
                                Image(systemName: "newspaper")
                                    .font(.title)
                                    .foregroundColor(.arkadGold.opacity(0.6))
                                
                                if imageLoadError {
                                    Text("Image unavailable")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                }
                .onAppear {
                    if article.imageUrl == nil {
                        imageLoadError = true
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Source and time
                    HStack {
                        if let source = article.source {
                            Text(source.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                        }
                        
                        Spacer()
                        
                        Text(formatTimeAgo(article.publishedUtc))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Summary
                    if let summary = article.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Ticker symbols
                    if !article.tickerSymbols.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(article.tickerSymbols.prefix(3), id: \.self) { ticker in
                                    Text(ticker)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(3)
                                }
                            }
                        }
                    }
                }
                .frame(width: 280, alignment: .leading)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - News Article Card
struct NewsArticleCard: View {
    let article: MarketNewsArticle
    let onTap: () -> Void
    @State private var imageLoadError = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Article image
                AsyncImage(url: URL(string: article.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.arkadGold.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "newspaper")
                                .font(.title3)
                                .foregroundColor(.arkadGold.opacity(0.6))
                        )
                }
                .onAppear {
                    if article.imageUrl == nil {
                        imageLoadError = true
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Source and time
                    HStack {
                        if let source = article.source {
                            Text(source.uppercased())
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.arkadGold)
                        }
                        
                        Spacer()
                        
                        Text(formatTimeAgo(article.publishedUtc))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Summary
                    if let summary = article.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Ticker symbols
                    if !article.tickerSymbols.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(article.tickerSymbols.prefix(3), id: \.self) { ticker in
                                    Text(ticker)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(3)
                                }
                                
                                if article.tickerSymbols.count > 3 {
                                    Text("+\(article.tickerSymbols.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Article Detail View
struct ArticleDetailView: View {
    let article: MarketNewsArticle
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingOriginalArticle = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header image
                    if let imageUrl = article.imageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.arkadGold.opacity(0.1))
                                .frame(height: 200)
                                .overlay(
                                    ProgressView()
                                        .tint(.arkadGold)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Source and date
                        HStack {
                            if let source = article.source {
                                Text(source.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.arkadGold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.arkadGold.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text(article.publishedUtc.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Title
                        Text(article.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Summary/Description
                        if let description = article.description ?? article.summary {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                        
                        // Ticker symbols
                        if !article.tickerSymbols.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Related Symbols")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(article.tickerSymbols, id: \.self) { ticker in
                                            Button(action: {
                                                homeViewModel.applyTickerFilter(ticker)
                                                dismiss()
                                            }) {
                                                Text(ticker)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Keywords
                        if !article.keywords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Keywords")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(article.keywords, id: \.self) { keyword in
                                            Text(keyword)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.secondary.opacity(0.1))
                                                .foregroundColor(.secondary)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Read full article button
                        if let articleUrl = article.articleUrl {
                            Button(action: {
                                showingOriginalArticle = true
                            }) {
                                HStack {
                                    Text("Read Full Article")
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.arkadGold)
                                .cornerRadius(8)
                            }
                            .sheet(isPresented: $showingOriginalArticle) {
                                SafariView(url: URL(string: articleUrl)!)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let articleUrl = article.articleUrl {
                        Button(action: {
                            UIPasteboard.general.string = articleUrl
                        }) {
                            Image(systemName: "link")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Empty News View
struct EmptyNewsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 50))
                .foregroundColor(.arkadGold.opacity(0.6))
            
            Text("No News Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Market news will appear here when available. Check back later for the latest updates.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}