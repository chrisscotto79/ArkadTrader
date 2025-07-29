// File: Core/Communities/Services/LeaderboardCalculationService.swift
// Fixed to use correct Firebase methods from your existing services

import Foundation

@MainActor
class LeaderboardCalculationService: ObservableObject {
    
    static let shared = LeaderboardCalculationService()
    
    private let authService = FirebaseAuthService.shared
    
    private init() {}
    
    /// Calculate leaderboard entries for a community - simplified for now
    func calculateLeaderboard(for communityId: String) async -> [CommunityLeaderboardEntry] {
        print("📊 Calculating leaderboard for community: \(communityId)")
        
        var entries: [CommunityLeaderboardEntry] = []
        
        // Check if we have a current user
        guard let currentUser = authService.currentUser else {
            print("❌ No current user found")
            return entries
        }
        
        print("✅ Current user: \(currentUser.username) (ID: \(currentUser.id))")
        
        do {
            print("🔍 Fetching trades for user: \(currentUser.id)")
            // Use the simple query to avoid Firebase index requirement
            let userTrades = try await authService.getUserTradesSimple(userId: currentUser.id)
            print("📈 Found \(userTrades.count) total trades")
            
            let closedTrades = userTrades.filter { !$0.isOpen }
            print("📈 Found \(closedTrades.count) closed trades")
            
            if closedTrades.isEmpty {
                print("⚠️ No closed trades found - cannot calculate stats")
                return entries
            }
            
            let totalTrades = closedTrades.count
            let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
            let winRate = Double(winningTrades) / Double(totalTrades) * 100
            let totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
            
            print("📊 Stats calculated:")
            print("   - Total trades: \(totalTrades)")
            print("   - Winning trades: \(winningTrades)")
            print("   - Win rate: \(String(format: "%.1f", winRate))%")
            print("   - Total P&L: $\(String(format: "%.2f", totalProfitLoss))")
            
            let entry = CommunityLeaderboardEntry(
                userId: currentUser.id,
                username: currentUser.username,
                communityId: communityId,
                totalTrades: totalTrades,
                winRate: winRate,
                totalProfitLoss: totalProfitLoss
            )
            
            var rankedEntry = entry
            rankedEntry.rank = 1
            entries.append(rankedEntry)
            
            print("✅ Added current user entry successfully")
            
        } catch {
            print("❌ Error getting current user trades: \(error)")
        }
        
        print("✅ Calculated leaderboard with \(entries.count) entries")
        return entries
    }
    
    /// Get user stats from trades
    func getUserStats(userId: String) async -> (totalTrades: Int, winRate: Double, totalProfitLoss: Double) {
        print("📈 Getting stats for user: \(userId)")
        
        do {
            let userTrades = try await authService.getUserTrades(userId: userId)
            let closedTrades = userTrades.filter { !$0.isOpen }
            
            guard !closedTrades.isEmpty else {
                return (totalTrades: 0, winRate: 0.0, totalProfitLoss: 0.0)
            }
            
            let totalTrades = closedTrades.count
            let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
            let winRate = Double(winningTrades) / Double(totalTrades) * 100
            let totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
            
            return (totalTrades: totalTrades, winRate: winRate, totalProfitLoss: totalProfitLoss)
            
        } catch {
            print("❌ Error getting user stats: \(error)")
            return (totalTrades: 0, winRate: 0.0, totalProfitLoss: 0.0)
        }
    }
}
