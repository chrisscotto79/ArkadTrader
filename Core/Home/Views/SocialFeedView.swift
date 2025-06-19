//
//  SocialFeedView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Core/Home/Views/SocialFeedView.swift

import SwiftUI

struct SocialFeedView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<10, id: \.self) { index in
                    SocialPostCard(index: index)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .refreshable {
            homeViewModel.refreshPosts()
        }
    }
}

struct SocialPostCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(format: "%c", 65 + index)) // A, B, C, etc.
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading) {
                    Text("Trader\(index + 1)")
                        .fontWeight(.semibold)
                    Text("2h ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
            }
            
            Text(getSamplePostContent(for: index))
                .font(.body)
            
            if index % 3 == 0 {
                // Some posts have trade results
                HStack {
                    VStack(alignment: .leading) {
                        Text("AAPL")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("+12.5%")
                            .font(.headline)
                            .foregroundColor(.marketGreen)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.marketGreen.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
            
            HStack {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "heart")
                        Text("\(Int.random(in: 5...50))")
                    }
                    .foregroundColor(.gray)
                    .font(.caption)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "message")
                        Text("\(Int.random(in: 1...15))")
                    }
                    .foregroundColor(.gray)
                    .font(.caption)
                }
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .foregroundColor(.gray)
                    .font(.caption)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)
    }
    
    private func getSamplePostContent(for index: Int) -> String {
        let posts = [
            "Just closed my AAPL position with a +15% gain! 📈 Market sentiment looking bullish.",
            "Anyone else watching TSLA today? Thinking about entering a position 🤔",
            "Great day in the markets! My portfolio is up 3.2% today 🚀",
            "NVDA earnings coming up next week. What's everyone's thoughts?",
            "Loving this bull run! SPY hitting new highs 📊",
            "Just started my trading journey. Any tips for a beginner?",
            "Bitcoin looking strong today. Crypto winter might be over! ₿",
            "Closed my short position on QQQ. This rally is stronger than expected.",
            "Anyone trading options on AMZN? Volume looks interesting today.",
            "Market volatility is wild today. Perfect for day trading! ⚡"
        ]
        return posts[index % posts.count]
    }
}

#Preview {
    SocialFeedView()
}
