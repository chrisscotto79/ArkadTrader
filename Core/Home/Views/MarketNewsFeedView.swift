// Fixed MarketNewsFeedView.swift
// Replace the problematic sections with this clean implementation

import SwiftUI

struct MarketNewsFeedView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @State private var selectedArticle: MarketNewsArticle?
    @State private var showingArticleDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if homeViewModel.isLoadingNews {
                            loadingSection
                        } else if homeViewModel.marketNews.isEmpty {
                            emptyStateSection
                        } else {
                            allNewsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                .refreshable {
                    await homeViewModel.loadMarketNews()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await homeViewModel.loadMarketNews()
            }
        }
        .sheet(isPresented: $showingArticleDetail) {
            if let selectedArticle = selectedArticle {
                ArticleDetailView(article: selectedArticle)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Latest News")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
        }
    }
    
    private var allNewsSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(homeViewModel.getRegularNews(), id: \.id) { article in
                NewsArticleCard(article: article) {
                    selectedArticle = article
                    showingArticleDetail = true
                }
            }
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading latest news...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No News Available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Check back later for the latest market news and updates.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Refresh") {
                Task {
                    await homeViewModel.loadMarketNews()
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.arkadGold)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.arkadGold.opacity(0.1))
            .cornerRadius(25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - News Article Card

struct NewsArticleCard: View {
    let article: MarketNewsArticle
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Image (if available)
                if let imageUrl = article.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .cornerRadius(12)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 160)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Source and category
                    HStack {
                        if let source = article.source {
                            Text(source.uppercased())
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.arkadGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.arkadGold.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Text(formatDate(article.publishedUtc))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Title
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Description
                    if let description = article.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Keywords
                    if !article.keywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(article.keywords.prefix(3)), id: \.self) { keyword in
                                    Text("#\(keyword)")
                                        .font(.caption)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = formatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        
        return "Recently"
    }
}

// MARK: - Article Detail View

struct ArticleDetailView: View {
    let article: MarketNewsArticle
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header image
                    if let imageUrl = article.imageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 250)
                                .overlay(ProgressView())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Source and date
                        HStack {
                            if let source = article.source {
                                Text(source.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.arkadGold)
                            }
                            
                            Spacer()
                            
                            Text(formatDetailDate(article.publishedUtc))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Title
                        Text(article.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Description
                        if let description = article.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                        
                        // Read more button
                        Button("Read Full Article") {
                            if let url = URL(string: article.articleUrl) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.arkadGold)
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("News")
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
    
    private func formatDetailDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

#Preview {
    MarketNewsFeedView(homeViewModel: HomeViewModel())
}
