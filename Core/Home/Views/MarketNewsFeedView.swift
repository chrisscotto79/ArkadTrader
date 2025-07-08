// File: Core/Home/Views/MarketNewsFeedView.swift
// Market News Feed View with Trending Section

import SwiftUI

struct MarketNewsFeedView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedArticle: MarketNewsArticle?
    @State private var showingArticleDetail = false
    
    var body: some View {
        ZStack {
            if homeViewModel.isLoadingNews {
                LoadingNewsView()
            } else if homeViewModel.marketNews.isEmpty {
                EmptyNewsView {
                    Task {
                        await homeViewModel.loadMarketNews()
                    }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Trending News Section
                        trendingNewsSection
                        
                        // All News Section
                        allNewsSection
                    }
                    .padding(.bottom, 80) // Space for tab bar
                }
                .refreshable {
                    await homeViewModel.loadMarketNews()
                }
            }
        }
        .onAppear {
            Task {
                await homeViewModel.loadMarketNews()
            }
        }
        .sheet(isPresented: $showingArticleDetail) {
            if let article = selectedArticle {
                ArticleDetailView(article: article)
            }
        }
    }
    
    // MARK: - Trending News Section
    private var trendingNewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(homeViewModel.getTrendingNews(), id: \.id) { article in
                        TrendingNewsCard(article: article) {
                            selectedArticle = article
                            showingArticleDetail = true
                        }
                    }
                }
                .padding(.horizontal)
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
                .padding(.horizontal)
            
            LazyVStack(spacing: 16) {
                ForEach(homeViewModel.getRegularNews(), id: \.id) { article in
                    NewsArticleCard(article: article) {
                        selectedArticle = article
                        showingArticleDetail = true
                    }
                    .padding(.horizontal)
                }
            }
        }
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
                // Image
                if let imageUrl = article.imageUrl, !imageUrl.isEmpty, !imageLoadError {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 280, height: 160)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                                .cornerRadius(12)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 160)
                                .clipped()
                                .cornerRadius(12)
                        case .failure(_):
                            newsImagePlaceholder
                                .onAppear { imageLoadError = true }
                        @unknown default:
                            newsImagePlaceholder
                        }
                    }
                } else {
                    newsImagePlaceholder
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Source and Time
                    HStack {
                        Text(article.source ?? "Market News")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(formatNewsDate(article.publishedUtc))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    // Category Tag
                    if let category = article.category {
                        Text(category.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(categoryColor(for: category))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(width: 280)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var newsImagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 280, height: 160)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "newspaper.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue.opacity(0.5))
                    Text("ArkadTrader News")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.7))
                }
            )
            .cornerRadius(12)
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "general": return .blue
        case "forex": return .green
        case "crypto": return .orange
        case "merger": return .purple
        default: return .gray
        }
    }
    
    private func formatNewsDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: dateString) else { return "Recent" }
        
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
            HStack(alignment: .top, spacing: 16) {
                // Article Image
                if let imageUrl = article.imageUrl, !imageUrl.isEmpty, !imageLoadError {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            imagePlaceholder
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(12)
                        case .failure(_):
                            imagePlaceholder
                                .onAppear { imageLoadError = true }
                        @unknown default:
                            imagePlaceholder
                        }
                    }
                } else {
                    imagePlaceholder
                }
                
                // Article Content
                VStack(alignment: .leading, spacing: 8) {
                    // Source
                    HStack {
                        Image(systemName: "newspaper")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(article.source ?? "Market News")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    // Description
                    if let description = article.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Time
                    Text(formatNewsDate(article.publishedUtc))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.1))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "newspaper")
                    .font(.title2)
                    .foregroundColor(.blue.opacity(0.5))
            )
            .cornerRadius(12)
    }
    
    private func formatNewsDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: dateString) else { return "Recent" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Article Detail View
struct ArticleDetailView: View {
    let article: MarketNewsArticle
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var imageLoadError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Article Image
                    if let imageUrl = article.imageUrl, !imageUrl.isEmpty, !imageLoadError {
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .empty:
                                detailImagePlaceholder
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxHeight: 250)
                                    .clipped()
                                    .cornerRadius(16)
                            case .failure(_):
                                detailImagePlaceholder
                                    .onAppear { imageLoadError = true }
                            @unknown default:
                                detailImagePlaceholder
                            }
                        }
                    } else {
                        detailImagePlaceholder
                    }
                    
                    // Article Info
                    VStack(alignment: .leading, spacing: 16) {
                        // Source and Date
                        HStack {
                            Label(article.source ?? "Market News", systemImage: "newspaper")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text(formatDetailDate(article.publishedUtc))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Title
                        Text(article.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineSpacing(4)
                        
                        // Category Tags
                        if !article.keywords.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(article.keywords.prefix(5)), id: \.self) { keyword in
                                        Text(keyword)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        
                        // Description
                        if let description = article.description {
                            Text(description)
                                .font(.body)
                                .lineSpacing(6)
                        }
                        
                        // Read Full Article Button
                        Button(action: {
                            if let url = URL(string: article.articleUrl), UIApplication.shared.canOpenURL(url) {
                                openURL(url)
                            }
                        }) {
                            HStack {
                                Text("Read Full Article")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: URL(string: article.articleUrl) ?? URL(string: "https://arkadtrader.com")!) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    private var detailImagePlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 250)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue.opacity(0.5))
                    Text("ArkadTrader News")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.7))
                }
            )
            .cornerRadius(16)
    }
    
    private func formatDetailDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: dateString) else { return "Recent" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty State Views

struct EmptyNewsView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Market News")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We couldn't fetch the latest market news. Please check your connection and try again.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

struct LoadingNewsView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading market news...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    MarketNewsFeedView()
}
