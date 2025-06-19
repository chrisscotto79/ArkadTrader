//
//  MarketNewsFeedView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Core/Home/Views/MarketNewsFeedView.swift

import SwiftUI

struct MarketNewsFeedView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<15, id: \.self) { index in
                    NewsCard(index: index)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .refreshable {
            // TODO: Refresh news
        }
    }
}

struct NewsCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getNewsSource(for: index))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.arkadGold)
                    
                    Text(getTimeAgo(for: index))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Market impact indicator
                getMarketImpact(for: index)
            }
            
            Text(getNewsHeadline(for: index))
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(3)
            
            Text(getNewsDescription(for: index))
                .font(.body)
                .foregroundColor(.gray)
                .lineLimit(3)
            
            // Related stocks/symbols
            HStack {
                ForEach(getRelatedSymbols(for: index), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.arkadGold.opacity(0.1))
                        .foregroundColor(.arkadGold)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 1)
    }
    
    private func getNewsSource(for index: Int) -> String {
        let sources = ["Bloomberg", "Reuters", "CNBC", "MarketWatch", "Yahoo Finance", "Financial Times", "Wall Street Journal"]
        return sources[index % sources.count]
    }
    
    private func getTimeAgo(for index: Int) -> String {
        let times = ["5m ago", "15m ago", "1h ago", "2h ago", "3h ago", "5h ago", "1d ago"]
        return times[index % times.count]
    }
    
    private func getMarketImpact(for index: Int) -> some View {
        let impacts = ["High", "Medium", "Low"]
        let colors: [Color] = [.marketRed, .arkadGold, .marketGreen]
        let impact = impacts[index % impacts.count]
        let color = colors[index % colors.count]
        
        return Text(impact)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    private func getNewsHeadline(for index: Int) -> String {
        let headlines = [
            "Fed Signals Potential Rate Cut as Inflation Cools",
            "Tech Stocks Rally on Strong AI Earnings Reports",
            "Oil Prices Surge Amid Middle East Tensions",
            "Bitcoin Breaks $50,000 as Institutional Adoption Grows",
            "Apple Reports Record iPhone Sales in Q3",
            "Tesla Unveils New Model with 400-Mile Range",
            "JPMorgan CEO Warns of Economic Headwinds",
            "NVIDIA Stock Jumps 15% on AI Chip Demand",
            "Gold Hits All-Time High as Dollar Weakens",
            "Amazon Announces Major Warehouse Expansion",
            "Microsoft Azure Revenue Exceeds Expectations",
            "Energy Stocks Outperform Amid Supply Concerns",
            "Meta's Reality Labs Shows Signs of Progress",
            "Banking Sector Faces New Regulatory Challenges",
            "Crypto Market Cap Reaches $2 Trillion Milestone"
        ]
        return headlines[index % headlines.count]
    }
    
    private func getNewsDescription(for index: Int) -> String {
        let descriptions = [
            "Federal Reserve officials indicated a dovish stance in their latest meeting, suggesting that interest rate cuts may be on the horizon as inflation continues to moderate.",
            "Major technology companies reported stronger-than-expected earnings driven by artificial intelligence initiatives, boosting investor confidence in the sector.",
            "Crude oil futures spiked following geopolitical developments in the Middle East, raising concerns about global supply disruptions.",
            "The world's largest cryptocurrency reached a significant milestone as more institutional investors embrace digital assets as a store of value.",
            "Apple's latest quarterly results showed robust demand for its flagship smartphone, despite concerns about market saturation.",
            "Electric vehicle manufacturer announced breakthrough in battery technology that could revolutionize the industry's range capabilities.",
            "The banking giant's chief executive outlined potential economic challenges ahead, citing concerns about commercial real estate and consumer debt.",
            "Semiconductor company's shares soared as demand for artificial intelligence chips continues to outpace supply significantly.",
            "Precious metals reached record levels as investors seek safe-haven assets amid currency volatility and inflation concerns.",
            "E-commerce leader revealed plans for significant infrastructure investment to meet growing demand for faster delivery services.",
            "Cloud computing division's impressive growth helped drive overall revenue above analyst expectations for the quarter.",
            "Traditional energy companies are benefiting from supply constraints and increased demand as economies reopen globally.",
            "Social media company's virtual reality division showed encouraging progress in user adoption and revenue generation.",
            "New financial regulations could significantly impact lending practices and profitability across the banking industry.",
            "Digital asset market capitalization milestone reflects growing mainstream acceptance and institutional investment flows."
        ]
        return descriptions[index % descriptions.count]
    }
    
    private func getRelatedSymbols(for index: Int) -> [String] {
        let symbolSets = [
            ["SPY", "QQQ"],
            ["AAPL", "MSFT", "GOOGL"],
            ["XOM", "CVX"],
            ["BTC", "ETH"],
            ["AAPL"],
            ["TSLA"],
            ["JPM", "BAC"],
            ["NVDA"],
            ["GLD", "SLV"],
            ["AMZN"],
            ["MSFT"],
            ["XLE"],
            ["META"],
            ["XLF"],
            ["BTC", "COIN"]
        ]
        return symbolSets[index % symbolSets.count]
    }
}

#Preview {
    MarketNewsFeedView()
}
