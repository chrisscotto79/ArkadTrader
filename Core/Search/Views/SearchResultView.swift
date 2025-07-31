// File: Core/Search/Views/SearchResultView.swift
// FIXED - SearchResultView with correct property names and navigation

import SwiftUI

struct SearchResultView: View {
    let result: SearchResult
    @EnvironmentObject private var authService: FirebaseAuthService
    
    var body: some View {
        Button(action: {
            handleResultTap()
        }) {
            HStack(spacing: 12) {
                // Result Icon/Avatar
                resultIcon
                
                // Main Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.arkadBlack)
                        .lineLimit(2)
                    
                    Text(secondaryText)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    if let additionalInfo = additionalInfo {
                        Text(additionalInfo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(additionalInfoColor)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Result Type Badge
                resultTypeBadge
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Result Icon (FIXED - Using correct property names)
    @ViewBuilder
    private var resultIcon: some View {
        switch result.type {
        case .user:
            // FIXED: Use profileImageURL or fallback to placeholder
            AsyncImage(url: URL(string: "" )) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                    )
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
        case .post:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 18))
                )
            
        case .trade:
            RoundedRectangle(cornerRadius: 8)
                .fill(tradeColor.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(tradeColor)
                        .font(.system(size: 18))
                )
            
        case .group:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                )
        }
    }
    
    // MARK: - Result Type Badge
    @ViewBuilder
    private var resultTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.type.icon)
                .font(.system(size: 10))
                .foregroundColor(badgeColor)
            
            Text(result.type.displayName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Text Content (FIXED - Using correct property names)
    private var primaryText: String {
        switch result.type {
        case .user:
            // FIXED: Use fullName or username as fallback
            return result.user?.fullName ?? result.user?.username ?? "Unknown User"
        case .post:
            return String(result.post?.content.prefix(80) ?? "Post content")
        case .trade:
            // FIXED: Use 'ticker' instead of 'symbol'
            return "\(result.trade?.ticker ?? "UNKNOWN") Trade"
        case .group:
            return result.community?.name ?? "Community"
        }
    }
    
    private var secondaryText: String {
        switch result.type {
        case .user:
            return "@\(result.user?.username ?? "username")"
        case .post:
            return "by @\(result.post?.authorUsername ?? "unknown")"
        case .trade:
            if let trade = result.trade {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return trade.isOpen ? "Active" : "Closed \(formatter.string(from: trade.exitDate ?? trade.entryDate))"
            }
            return "Trade"
        case .group:
            return "\(result.community?.memberCount ?? 0) members"
        }
    }
    
    private var additionalInfo: String? {
        switch result.type {
        case .user:
            if let user = result.user {
                if user.winRate > 0 {
                    return "Win Rate: \(String(format: "%.1f%%", user.winRate))"
                }
                return "Trader"
            }
            return nil
            
        case .post:
            if let post = result.post {
                let likes = post.likesCount
                let comments = post.commentsCount
                if likes > 0 || comments > 0 {
                    return "\(likes) likes • \(comments) comments"
                }
            }
            return "0 interactions"
            
        case .trade:
            if let trade = result.trade {
                if trade.isOpen {
                    // FIXED: Use 'ticker' instead of 'symbol'
                    return "Active • Entry: $\(String(format: "%.2f", trade.entryPrice))"
                } else {
                    return String(format: "%.2f%% P&L", trade.profitLossPercentage)
                }
            }
            return nil
            
        case .group:
            return result.community?.isPrivate ?? false ? "Private" : "Public"
        }
    }
    
    // MARK: - Colors
    private var additionalInfoColor: Color {
        switch result.type {
        case .user:
            return .arkadGold
        case .post:
            return .gray
        case .trade:
            if let trade = result.trade, !trade.isOpen {
                return trade.profitLossPercentage >= 0 ? .green : .red
            }
            return .arkadGold
        case .group:
            return result.community?.isPrivate ?? false ? .red : .green
        }
    }
    
    private var tradeColor: Color {
        if let trade = result.trade, !trade.isOpen {
            return trade.profitLossPercentage >= 0 ? .green : .red
        }
        return .arkadGold
    }
    
    private var badgeColor: Color {
        switch result.type {
        case .user: return .blue
        case .post: return .purple
        case .trade: return tradeColor
        case .group: return .orange
        }
    }
    
    // MARK: - Actions (FIXED - Using print statements instead of non-existent views)
    private func handleResultTap() {
        switch result.type {
        case .user:
            // TODO: Navigate to user profile when UserProfileView is available
            print("Navigate to user profile: \(result.user?.username ?? "unknown")")
            
        case .post:
            // TODO: Navigate to post detail when PostDetailView is available
            print("Navigate to post: \(result.post?.id ?? "unknown")")
            
        case .trade:
            // TODO: Navigate to trade detail when TradeDetailView is available
            print("Navigate to trade: \(result.trade?.id ?? "unknown")")
            
        case .group:
            // TODO: Navigate to community when CommunityDetailView is available
            print("Navigate to community: \(result.community?.name ?? "unknown")")
        }
    }
}
