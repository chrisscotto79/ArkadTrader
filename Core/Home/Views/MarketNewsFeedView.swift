// File: Core/Home/Views/MarketNewsFeedView.swift
// Temporary implementation without Cloud Functions

import SwiftUI

struct MarketNewsFeedView: View {
    @StateObject private var viewModel = MarketNewsViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading market news...")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(viewModel.newsItems) { item in
                        NewsCard(news: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .refreshable {
            await viewModel.fetchNews()
        }
        .onAppear {
            Task {
                await viewModel.fetchNews()
            }
        }
    }
}

// MARK: - Safe News ViewModel (No External APIs)
@MainActor
class MarketNewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading = false
    
    func fetchNews() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Use curated placeholder news for now
        await MainActor.run {
            self.newsItems = createCuratedNews()
            self.isLoading = false
        }
    }
    
    private func createCuratedNews() -> [NewsItem] {
        let currentDate = Date()
        
        return [
            NewsItem(
                id: UUID().uuidString,
                headline: "Tech Stocks Rally as AI Investments Surge",
                summary: "Major technology companies see significant gains following increased AI infrastructure spending announcements",
                source: "Market Update",
                createdAt: currentDate.addingTimeInterval(-1800), // 30 min ago
                url: nil,
                symbols: ["AAPL", "MSFT", "NVDA", "GOOGL"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Federal Reserve Signals Potential Rate Adjustments",
                summary: "Central bank officials discuss monetary policy outlook in latest economic assessment",
                source: "Economic News",
                createdAt: currentDate.addingTimeInterval(-3600), // 1 hour ago
                url: nil,
                symbols: ["SPY", "TLT", "DXY"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Energy Sector Sees Mixed Results Amid Oil Price Volatility",
                summary: "Energy companies report varied quarterly results as crude oil prices remain volatile",
                source: "Sector News",
                createdAt: currentDate.addingTimeInterval(-5400), // 1.5 hours ago
                url: nil,
                symbols: ["XOM", "CVX", "USO"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Banking Sector Update: Regional Banks Show Resilience",
                summary: "Regional banking institutions demonstrate strong fundamentals despite market concerns",
                source: "Financial News",
                createdAt: currentDate.addingTimeInterval(-7200), // 2 hours ago
                url: nil,
                symbols: ["JPM", "BAC", "WFC", "KRE"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Cryptocurrency Market Experiences Renewed Interest",
                summary: "Digital assets gain momentum as institutional adoption continues to grow",
                source: "Crypto News",
                createdAt: currentDate.addingTimeInterval(-9000), // 2.5 hours ago
                url: nil,
                symbols: ["BTC", "ETH", "COIN"]
            ),
            NewsItem(
                id: UUID().uuidString,
                headline: "Healthcare Innovation Drives Biotech Gains",
                summary: "Pharmaceutical and biotech companies advance on breakthrough therapy announcements",
                source: "Healthcare News",
                createdAt: currentDate.addingTimeInterval(-10800), // 3 hours ago
                url: nil,
                symbols: ["JNJ", "PFE", "MRNA", "IBB"]
            )
        ]
    }
}

// MARK: - News Models (Same as before)
struct NewsItem: Identifiable, Codable {
    let id: String
    let headline: String
    let summary: String?
    let source: String
    let createdAt: Date
    let url: String?
    let symbols: [String]
}

struct NewsCard: View {
    let news: NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(news.source)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                    
                    Text(formatDate(news.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // News category emoji
                Text(getNewsEmoji(for: news.source))
                    .font(.title2)
            }
            
            Text(news.headline)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let summary = news.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
            }
            
            if !news.symbols.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(news.symbols.prefix(6), id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.arkadGold.opacity(0.15))
                                .foregroundColor(.arkadGold)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("\(Int.random(in: 5...25))")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                        Text("\(Int.random(in: 1...8))")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func getNewsEmoji(for source: String) -> String {
        switch source.lowercased() {
        case let s where s.contains("tech"): return "💻"
        case let s where s.contains("economic"): return "💰"
        case let s where s.contains("energy"): return "⚡"
        case let s where s.contains("financial"), let s where s.contains("bank"): return "🏦"
        case let s where s.contains("crypto"): return "₿"
        case let s where s.contains("health"): return "🏥"
        default: return "📈"
        }
    }
}

// MARK: - Future Cloud Function Implementation
/*
When you're ready to upgrade to Firebase Blaze plan, replace the fetchNews() method with:

func fetchNews() async {
    isLoading = true
    
    do {
        // Call Firebase Cloud Function
        let functions = Functions.functions()
        let callable = functions.httpsCallable("getMarketNews")
        
        let result = try await callable.call()
        
        if let data = result.data as? [[String: Any]] {
            let newsItems = data.compactMap { dict -> NewsItem? in
                // Parse news data from Cloud Function
                return try? NewsItem.fromDictionary(dict)
            }
            
            await MainActor.run {
                self.newsItems = newsItems
                self.isLoading = false
            }
        }
    } catch {
        print("Error fetching news: \(error)")
        await MainActor.run {
            // Fallback to curated news
            self.newsItems = createCuratedNews()
            self.isLoading = false
        }
    }
}
*/

#Preview {
    MarketNewsFeedView()
}
