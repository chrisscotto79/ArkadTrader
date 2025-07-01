//
//  MarketNewsFeedView.swift
//  ArkadTrader
//

import SwiftUI

struct MarketNewsFeedView: View {
    @StateObject private var newsFetcher = PolygonNewsFetcher()
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(newsFetcher.newsItems) { item in
                    LiveNewsCard(news: item)
                }

                if newsFetcher.newsItems.isEmpty {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading news from Polygon.io...")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 50)
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
        .refreshable {
            newsFetcher.fetchNews()
        }
    }

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            newsFetcher.fetchNews()
        }
    }

    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - News Fetcher
class PolygonNewsFetcher: ObservableObject {
    @Published var newsItems: [PolygonNewsItem] = []

    private let apiKey = "x3gVFWOZqHWtmYIz770auaj576WSF2Fh"

    func fetchNews() {
        guard let url = URL(string: "https://api.polygon.io/v2/reference/news?limit=20&apiKey=\(apiKey)") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("❌ Fetch error: \(error)")
                return
            }

            guard let data = data else { return }

            do {
                let decoded = try JSONDecoder().decode(PolygonNewsResponse.self, from: data)
                DispatchQueue.main.async {
                    var newItems = decoded.results ?? []
                    newItems.removeAll { item in
                        self?.newsItems.contains(where: { $0.id == item.id }) ?? false
                    }
                    self?.newsItems.insert(contentsOf: newItems, at: 0)
                }
            } catch {
                print("⚠️ Decode error: \(error)")
            }
        }.resume()
    }
}

struct PolygonNewsResponse: Decodable {
    let results: [PolygonNewsItem]?
}

// MARK: - News Model
struct PolygonNewsItem: Identifiable, Decodable {
    let id: String
    let title: String
    let description: String?
    let published_utc: String
    let article_url: String?
    let tickers: [String]

    var headline: String { title }
    var summary: String? { description }
    var url: String? { article_url }
    var symbols: [String] { Array(tickers.prefix(6)) }

    var timestamp: Double {
        ISO8601DateFormatter().date(from: published_utc)?.timeIntervalSince1970 ?? 0
    }

    var createdAt: Date {
        Date(timeIntervalSince1970: timestamp)
    }

    var source: String {
        return "Polygon"
    }
}

// MARK: - News Card View
struct LiveNewsCard: View {
    let news: PolygonNewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(news.source)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)

                    Text(formatDate(news.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Live")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }

            Text(news.headline)
                .font(.headline)
                .fontWeight(.semibold)

            if let summary = news.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            if !news.symbols.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(news.symbols.prefix(6), id: \ .self) { symbol in
                            Text(symbol)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            if let urlString = news.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("Read More")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview
#Preview {
    MarketNewsFeedView()
}
