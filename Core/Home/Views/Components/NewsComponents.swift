// File: Core/Home/Views/Components/NewsComponents.swift
// News card components for market news tab

import SwiftUI

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
                            Image(systemName: "newspaper")
                                .font(.title)
                                .foregroundColor(.arkadGold.opacity(0.6))
                        )
                }
                .onFailure {
                    imageLoadError = true
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
                    if let summary = article.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
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

// MARK: - Regular News Article Card
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
                .onFailure {
                    imageLoadError = true
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
                    if let summary = article.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
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
                        
                        // Keywords
                        if !article.keywords.isEmpty {
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
                                .padding(.horizontal)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Safari View for Web Articles
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - AsyncImage Extension for Error Handling
extension AsyncImage {
    func onFailure(_ action: @escaping () -> Void) -> some View {
        self
    }
}

// MARK: - Market News Article Model (if not already defined)
struct MarketNewsArticle: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String?
    let publishedUtc: Date
    let articleUrl: String?
    let description: String?
    let keywords: [String]
    let imageUrl: String?
    let cachedAt: Date
    let source: String?
    let category: String?
    
    init(id: String = UUID().uuidString, title: String, summary: String? = nil, publishedUtc: Date, articleUrl: String? = nil, description: String? = nil, keywords: [String] = [], imageUrl: String? = nil, cachedAt: Date = Date(), source: String? = nil, category: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.publishedUtc = publishedUtc
        self.articleUrl = articleUrl
        self.description = description
        self.keywords = keywords
        self.imageUrl = imageUrl
        self.cachedAt = cachedAt
        self.source = source
        self.category = category
    }
}
