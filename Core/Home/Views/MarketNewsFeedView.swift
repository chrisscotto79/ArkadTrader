// File: Core/Home/Views/MarketNewsFeedView.swift
// Simplified Market News Feed View

import SwiftUI

struct MarketNewsFeedView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<3) { _ in
                    NewsCard()
                }
            }
            .padding()
        }
    }
}

struct NewsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Market Update")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("Stocks rally as tech sector leads gains")
                .font(.headline)
            
            Text("Major indices closed higher today with technology stocks leading the way...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    MarketNewsFeedView()
}
