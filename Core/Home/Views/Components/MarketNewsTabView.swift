// File: Core/Home/Views/Components/MarketNewsTabView.swift
// Simple MarketNewsTabView for HomeView

import SwiftUI

struct MarketNewsTabView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var scrollToTopId = UUID()
    
    var body: some View {
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
            
            LazyVStack(spacing: 12) {
                ForEach(homeViewModel.getRegularNews(), id: \.id) { article in
                    NewsCard(article: article) {
                        handleArticleTap(article)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleArticleTap(_ article: MarketNewsArticle) {
        homeViewModel.selectedArticle = article
        // TODO: Navigate to article detail or open in Safari
    }
}

// MARK: - Supporting Views
struct TrendingNewsCard: View {
    let article: MarketNewsArticle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: article.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "newspaper")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 200, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if let source = article.source {
                        Text(source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(article.publishedUtc.timeAgoDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 200, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NewsCard: View {
    let article: MarketNewsArticle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: article.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "newspaper")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                        .foregroundColor(.primary)
                    
                    if let description = article.description {
                        Text(description)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if let source = article.source {
                            Text(source)
                                .font(.caption)
                                .foregroundColor(.arkadGold)
                        }
                        
                        Spacer()
                        
                        Text(article.publishedUtc.timeAgoDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Loading and Empty States
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.arkadGold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct LoadingMoreView: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.arkadGold)
            
            Text("Loading more...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct LoadMoreButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("Load More")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: "arrow.down.circle")
                    .font(.subheadline)
            }
            .foregroundColor(.arkadGold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
