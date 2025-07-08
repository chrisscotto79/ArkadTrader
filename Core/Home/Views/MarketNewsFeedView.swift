// File: Core/Home/Views/MarketNewsFeedView.swift
// Updated Market News Feed View with Polygon API Integration

import SwiftUI

struct MarketNewsFeedView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    
    var body: some View {
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
                LazyVStack(spacing: 20) {
                    // Trending News Horizontal Scroll
                    trendingNewsSection
                    
                    // All News Vertical List
                    ForEach(homeViewModel.getRegularNews(), id: \.id) { article in
                        MarketNewsCard(article: article)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80) // Space for floating button
            }
            .refreshable {
                await homeViewModel.loadMarketNews()
            }
            .onAppear {
                Task {
                    await homeViewModel.loadMarketNews()
                }
            }
        }
    }
    
    private var trendingNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trending")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("See All")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.top, 12) // Small padding to avoid being too close to tab bar
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(homeViewModel.getTrendingNews(), id: \.id) { article in
                        TrendingNewsCard(article: article)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - Market News Card (with improved image loading)
struct MarketNewsCard: View {
    let article: MarketNewsArticle
    @State private var showWebView = false
    @State private var imageLoadError = false
    
    var body: some View {
        Button(action: {
            if let url = URL(string: article.articleUrl), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Article image (if available)
                if let imageUrl = article.imageUrl, !imageUrl.isEmpty, !imageLoadError {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.2)
                                )
                                .cornerRadius(12)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        case .failure(_):
                            Rectangle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 200)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "newspaper")
                                            .font(.title)
                                            .foregroundColor(.blue)
                                        Text("Market News")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                )
                                .cornerRadius(12)
                                .onAppear {
                                    imageLoadError = true
                                }
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    // Fallback for no image
                    Rectangle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "newspaper")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                Text("Market News")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        )
                        .cornerRadius(12)
                }
                
                // News header
                HStack {
                    Image(systemName: "newspaper")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.author ?? "Market News")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(formatNewsDate(article.publishedUtc))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Article title and description
                VStack(alignment: .leading, spacing: 8) {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    if let description = article.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.gray)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // Keywords/tags
                if !article.keywords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(article.keywords.prefix(5)), id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Trending News Card (improved image loading)
struct TrendingNewsCard: View {
    let article: MarketNewsArticle
    @State private var imageLoadError = false
    
    var body: some View {
        Button(action: {
            if let url = URL(string: article.articleUrl), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Article image
                if let imageUrl = article.imageUrl, !imageUrl.isEmpty, !imageLoadError {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 120)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                                .cornerRadius(8)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 120)
                                .clipped()
                                .cornerRadius(8)
                        case .failure(_):
                            Rectangle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 200, height: 120)
                                .overlay(
                                    Image(systemName: "newspaper")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                )
                                .cornerRadius(8)
                                .onAppear {
                                    imageLoadError = true
                                }
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 120)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 200, height: 120)
                        .overlay(
                            Image(systemName: "newspaper")
                                .foregroundColor(.blue)
                                .font(.title2)
                        )
                        .cornerRadius(8)
                }
                
                // Article info
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatTrendingDate(article.publishedUtc))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Top keyword
                    if let firstKeyword = article.keywords.first {
                        Text(firstKeyword)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(width: 200)
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTrendingDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: dateString) else { return "Recent" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Empty State Views

struct EmptyNewsView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Market News Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Text("We're having trouble fetching the latest market news. Please try again later.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80) // Reduced to minimize white space
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
        .padding(.top, 100) // Reduced from default to minimize white space
    }
}

#Preview {
    MarketNewsFeedView()
}
