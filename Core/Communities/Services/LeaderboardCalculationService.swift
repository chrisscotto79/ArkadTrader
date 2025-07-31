// File: Core/Communities/Services/LeaderboardCalculationService.swift
// Fixed to use correct Firebase methods from your existing services

import Foundation

@MainActor
class LeaderboardCalculationService: ObservableObject {
    
    static let shared = LeaderboardCalculationService()
    
    private let authService = FirebaseAuthService.shared
    
    private init() {}
    
    /// Calculate leaderboard entries for a community - FIXED to include all members
    func calculateLeaderboard(for communityId: String) async -> [CommunityLeaderboardEntry] {
        print("📊 Calculating leaderboard for community: \(communityId)")
        
        var entries: [CommunityLeaderboardEntry] = []
        
        do {
            print("👥 Getting all community members...")
            // ✅ GET ALL COMMUNITY MEMBERS (not just current user)
            let communityMembers = try await FirebaseServices.shared.getCommunityMembers(communityId: communityId)
            print("✅ Found \(communityMembers.count) community members")
            
            // ✅ CALCULATE STATS FOR EACH MEMBER
            for member in communityMembers {
                print("📈 Calculating stats for: \(member.username)")
                
                do {
                    let userTrades = try await authService.getUserTrades(userId: member.id)
                    let closedTrades = userTrades.filter { !$0.isOpen }
                    
                    // Only include users with at least 1 trade
                    guard !closedTrades.isEmpty else {
                        print("⚠️ \(member.username) has no closed trades - skipping")
                        continue
                    }
                    
                    let totalTrades = closedTrades.count
                    let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
                    let winRate = Double(winningTrades) / Double(totalTrades) * 100
                    let totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
                    
                    print("📊 \(member.username) stats: \(totalTrades) trades, \(String(format: "%.1f", winRate))% win rate, $\(String(format: "%.2f", totalProfitLoss)) P&L")
                    
                    let entry = CommunityLeaderboardEntry(
                        userId: member.id,
                        username: member.username,
                        communityId: communityId,
                        totalTrades: totalTrades,
                        winRate: winRate,
                        totalProfitLoss: totalProfitLoss
                    )
                    
                    entries.append(entry)
                    
                } catch {
                    print("❌ Error getting trades for \(member.username): \(error)")
                    // Continue to next member instead of failing completely
                }
            }
            
            // ✅ SORT BY WIN RATE (you can change this logic later)
            entries.sort { $0.winRate > $1.winRate }
            
            // ✅ ASSIGN RANKS
            for i in 0..<entries.count {
                entries[i].rank = i + 1
            }
            
            print("✅ Final leaderboard: \(entries.count) entries")
            for entry in entries {
                print("   #\(entry.rank): \(entry.username) - \(String(format: "%.1f", entry.winRate))% win rate")
            }
            
        } catch {
            print("❌ Error calculating leaderboard: \(error)")
        }
        
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
