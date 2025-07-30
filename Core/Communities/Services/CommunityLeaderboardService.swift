// File: Core/Communities/Services/CommunityLeaderboardService.swift
// Complete Community Leaderboard Service with Global Support - Fixed Access Levels

import Foundation
import FirebaseFirestore

@MainActor
class CommunityLeaderboardService: ObservableObject {
    
    static let shared = CommunityLeaderboardService()
    
    private let calculationService = LeaderboardCalculationService.shared
    
    // ✅ Made internal for access from GlobalLeaderboardViewModel
    let authService = FirebaseAuthService.shared
    
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var lastUpdated: Date?
    
    // Cache for performance
    private var leaderboardCache: [String: [CommunityLeaderboardEntry]] = [:]
    private var globalLeaderboardCache: [CommunityLeaderboardEntry] = []
    private var cacheExpiry: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Community Leaderboards
    
    /// Get leaderboard for a specific community
    func getLeaderboard(
        communityId: String,
        category: LeaderboardCategory,
        timeframe: LeaderboardTimeframe = .allTime,
        limit: Int = 50
    ) async throws -> [CommunityLeaderboardEntry] {
        print("📊 Getting leaderboard for community: \(communityId)")
        
        // Check cache first
        let cacheKey = "\(communityId)_\(category.rawValue)_\(timeframe.rawValue)"
        if let cachedEntries = getCachedLeaderboard(key: cacheKey) {
            print("✅ Using cached leaderboard data")
            return cachedEntries
        }
        
        isLoading = true
        errorMessage = ""
        
        defer {
            isLoading = false
            lastUpdated = Date()
        }
        
        do {
            let entries: [CommunityLeaderboardEntry]
            
            switch category {
            case .consistencyMasters:
                entries = try await getConsistencyLeaderboard(
                    communityId: communityId,
                    timeframe: timeframe,
                    limit: limit
                )
            case .profitKings:
                entries = try await getProfitLeaderboard(
                    communityId: communityId,
                    timeframe: timeframe,
                    limit: limit
                )
            case .volumeTraders:
                entries = try await getVolumeLeaderboard(
                    communityId: communityId,
                    timeframe: timeframe,
                    limit: limit
                )
            case .riskMasters:
                entries = try await getRiskLeaderboard(
                    communityId: communityId,
                    timeframe: timeframe,
                    limit: limit
                )
            }
            
            // Cache the results
            cacheLeaderboard(key: cacheKey, entries: entries)
            
            return entries
            
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            print("❌ Error getting leaderboard: \(error)")
            throw error
        }
    }
    
    /// Get global leaderboard (all traders across all communities)
    func getGlobalLeaderboard(
        category: LeaderboardCategory,
        timeframe: LeaderboardTimeframe = .allTime,
        limit: Int = 100
    ) async throws -> [CommunityLeaderboardEntry] {
        print("🌍 Getting global leaderboard")
        
        // Check cache first
        let cacheKey = "global_\(category.rawValue)_\(timeframe.rawValue)"
        if let cachedEntries = getCachedLeaderboard(key: cacheKey) {
            print("✅ Using cached global leaderboard data")
            return cachedEntries
        }
        
        isLoading = true
        errorMessage = ""
        
        defer {
            isLoading = false
            lastUpdated = Date()
        }
        
        do {
            let entries = try await calculateGlobalLeaderboard(
                category: category,
                timeframe: timeframe,
                limit: limit
            )
            
            // Cache the results
            cacheLeaderboard(key: cacheKey, entries: entries)
            globalLeaderboardCache = entries
            
            return entries
            
        } catch {
            errorMessage = "Failed to load global leaderboard: \(error.localizedDescription)"
            print("❌ Error getting global leaderboard: \(error)")
            throw error
        }
    }
    
    // MARK: - Specific Leaderboard Types
    
    /// Get consistency-based leaderboard (win rate focused)
    private func getConsistencyLeaderboard(
        communityId: String,
        timeframe: LeaderboardTimeframe,
        limit: Int
    ) async throws -> [CommunityLeaderboardEntry] {
        print("🎯 Calculating consistency leaderboard")
        
        let communityMembers = try await getCommunityMembers(communityId: communityId)
        var entries: [CommunityLeaderboardEntry] = []
        
        for member in communityMembers {
            if let entry = await calculateMemberStats(
                userId: member.userId,
                username: member.username,
                communityId: communityId,
                timeframe: timeframe
            ) {
                // ✅ CHANGE: Lower minimum trades from 5 to 1 for testing
                if entry.totalTrades >= 1 { // Was: >= 5
                    entries.append(entry)
                }
            }
        }
        
        // Sort by win rate, then by total trades
        entries.sort { lhs, rhs in
            if lhs.winRate == rhs.winRate {
                return lhs.totalTrades > rhs.totalTrades
            }
            return lhs.winRate > rhs.winRate
        }
        
        // Assign ranks and limit results
        return assignRanks(to: entries, limit: limit)
    }
    
    /// Get profit-based leaderboard (total P&L focused)
    private func getProfitLeaderboard(
        communityId: String,
        timeframe: LeaderboardTimeframe,
        limit: Int
    ) async throws -> [CommunityLeaderboardEntry] {
        print("💰 Calculating profit leaderboard")
        
        let communityMembers = try await getCommunityMembers(communityId: communityId)
        var entries: [CommunityLeaderboardEntry] = []
        
        for member in communityMembers {
            if let entry = await calculateMemberStats(
                userId: member.userId,
                username: member.username,
                communityId: communityId,
                timeframe: timeframe
            ) {
                entries.append(entry)
            }
        }
        
        // Sort by total profit/loss
        entries.sort { $0.totalProfitLoss > $1.totalProfitLoss }
        
        return assignRanks(to: entries, limit: limit)
    }
    
    /// Get volume-based leaderboard (most active traders)
    private func getVolumeLeaderboard(
        communityId: String,
        timeframe: LeaderboardTimeframe,
        limit: Int
    ) async throws -> [CommunityLeaderboardEntry] {
        print("📊 Calculating volume leaderboard")
        
        let communityMembers = try await getCommunityMembers(communityId: communityId)
        var entries: [CommunityLeaderboardEntry] = []
        
        for member in communityMembers {
            if let entry = await calculateMemberStats(
                userId: member.userId,
                username: member.username,
                communityId: communityId,
                timeframe: timeframe
            ) {
                entries.append(entry)
            }
        }
        
        // Sort by total trades
        entries.sort { $0.totalTrades > $1.totalTrades }
        
        return assignRanks(to: entries, limit: limit)
    }
    
    /// Get risk management leaderboard (best risk/reward ratios)
    private func getRiskLeaderboard(
        communityId: String,
        timeframe: LeaderboardTimeframe,
        limit: Int
    ) async throws -> [CommunityLeaderboardEntry] {
        print("⚖️ Calculating risk leaderboard")
        
        let communityMembers = try await getCommunityMembers(communityId: communityId)
        var entries: [CommunityLeaderboardEntry] = []
        
        for member in communityMembers {
            if let entry = await calculateMemberStats(
                userId: member.userId,
                username: member.username,
                communityId: communityId,
                timeframe: timeframe
            ) {
                // Calculate risk score (combination of win rate and trade count)
                var riskScore = entry.winRate * 0.7 // 70% weight on win rate
                if entry.totalTrades >= 10 {
                    riskScore += Double(min(entry.totalTrades, 50)) * 0.6 // Bonus for experience
                }
                
                var scoredEntry = entry
                scoredEntry.score = riskScore
                entries.append(scoredEntry)
            }
        }
        
        // Sort by risk score
        entries.sort { $0.score > $1.score }
        
        return assignRanks(to: entries, limit: limit)
    }
    
    // MARK: - Global Leaderboard Calculation
    
    private func calculateGlobalLeaderboard(
        category: LeaderboardCategory,
        timeframe: LeaderboardTimeframe,
        limit: Int
    ) async throws -> [CommunityLeaderboardEntry] {
        print("🌍 Calculating global leaderboard for category: \(category)")
        
        // Get all users with trading activity
        let allUsers = try await getAllActiveTraders(timeframe: timeframe)
        var entries: [CommunityLeaderboardEntry] = []
        
        for user in allUsers {
            if let entry = await calculateMemberStats(
                userId: user.id,
                username: user.username,
                communityId: "global", // Use "global" as community ID
                timeframe: timeframe
            ) {
                entries.append(entry)
            }
        }
        
        // Sort based on category
        switch category {
        case .consistencyMasters:
            entries = entries.filter { $0.totalTrades >= 1 } // Was: >= 10
            entries.sort { lhs, rhs in
                if lhs.winRate == rhs.winRate {
                    return lhs.totalTrades > rhs.totalTrades
                }
                return lhs.winRate > rhs.winRate
            }
        case .profitKings:
            entries.sort { $0.totalProfitLoss > $1.totalProfitLoss }
        case .volumeTraders:
            entries.sort { $0.totalTrades > $1.totalTrades }
        case .riskMasters:
            entries = entries.filter { $0.totalTrades >= 5 }
            for i in 0..<entries.count {
                let winRate = entries[i].winRate
                let tradeCount = entries[i].totalTrades
                entries[i].score = winRate * 0.7 + Double(min(tradeCount, 100)) * 0.3
            }
            entries.sort { $0.score > $1.score }
        }
        
        return assignRanks(to: entries, limit: limit)
    }
    
    // MARK: - Helper Methods (Made Internal for Access)
    
    /// Get all active traders - ✅ Made internal
    func getAllActiveTraders(timeframe: LeaderboardTimeframe) async throws -> [User] {
        print("🌍 Getting all active traders for timeframe: \(timeframe)")
        
        var activeTraders: [User] = []
        
        // Get current user if they have trades
        if let currentUser = authService.currentUser {
            let userTrades = try await authService.getUserTradesSimple(userId: currentUser.id)
            let filteredTrades = filterTradesByTimeframe(trades: userTrades, timeframe: timeframe)
            
            if !filteredTrades.filter({ !$0.isOpen }).isEmpty {
                activeTraders.append(currentUser)
            }
        }
        
        // TODO: In production, you'd query Firebase for all users with recent trading activity
        // This would require a more sophisticated query structure
        
        return activeTraders
    }
    
    /// Get community members - ✅ Made internal
    func getCommunityMembers(communityId: String) async throws -> [CommunityMember] {
        print("👥 Getting members for community: \(communityId)")
        
        // For global leaderboard, we need all active traders
        if communityId == "global" {
            let activeTraders = try await getAllActiveTraders(timeframe: .allTime)
            return activeTraders.map { CommunityMember(userId: $0.id, username: $0.username) }
        }
        
        // For specific communities, get actual members
        // TODO: Implement real community member fetching from Firebase
        // For now, return current user as member if they exist
        guard let currentUser = authService.currentUser else {
            throw LeaderboardError.noCurrentUser
        }
        
        return [CommunityMember(userId: currentUser.id, username: currentUser.username)]
    }
    
    /// Calculate member statistics
    private func calculateMemberStats(
        userId: String,
        username: String,
        communityId: String,
        timeframe: LeaderboardTimeframe
    ) async -> CommunityLeaderboardEntry? {
        
        do {
            let userTrades = try await authService.getUserTradesSimple(userId: userId)
            let filteredTrades = filterTradesByTimeframe(trades: userTrades, timeframe: timeframe)
            let closedTrades = filteredTrades.filter { !$0.isOpen }
            
            guard !closedTrades.isEmpty else {
                return nil
            }
            
            let totalTrades = closedTrades.count
            let winningTrades = closedTrades.filter { $0.profitLoss > 0 }.count
            let winRate = Double(winningTrades) / Double(totalTrades) * 100
            let totalProfitLoss = closedTrades.reduce(0) { $0 + $1.profitLoss }
            
            return CommunityLeaderboardEntry(
                userId: userId,
                username: username,
                communityId: communityId,
                totalTrades: totalTrades,
                winRate: winRate,
                totalProfitLoss: totalProfitLoss
            )
            
        } catch {
            print("❌ Error calculating stats for user \(userId): \(error)")
            return nil
        }
    }
    
    /// Filter trades by timeframe - ✅ Made internal
    func filterTradesByTimeframe(trades: [Trade], timeframe: LeaderboardTimeframe) -> [Trade] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoffDate: Date
        
        switch timeframe {
        case .daily:
            cutoffDate = calendar.startOfDay(for: now)
        case .weekly:
            cutoffDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .monthly:
            cutoffDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .quarterly:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let quarterStartMonth = quarter * 3 + 1
            cutoffDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: quarterStartMonth,
                day: 1
            )) ?? now
        case .yearly:
            cutoffDate = calendar.dateInterval(of: .year, for: now)?.start ?? now
        case .allTime:
            return trades
        }
        
        return trades.filter { $0.entryDate >= cutoffDate }
    }
    
    /// Assign ranks to leaderboard entries
    private func assignRanks(to entries: [CommunityLeaderboardEntry], limit: Int) -> [CommunityLeaderboardEntry] {
        let limitedEntries = Array(entries.prefix(limit))
        
        return limitedEntries.enumerated().map { index, entry in
            var rankedEntry = entry
            rankedEntry.rank = index + 1
            return rankedEntry
        }
    }
    
    // MARK: - Cache Management
    
    private func getCachedLeaderboard(key: String) -> [CommunityLeaderboardEntry]? {
        guard let expiry = cacheExpiry[key],
              Date() < expiry,
              let cachedData = leaderboardCache[key] else {
            return nil
        }
        
        return cachedData
    }
    
    private func cacheLeaderboard(key: String, entries: [CommunityLeaderboardEntry]) {
        leaderboardCache[key] = entries
        cacheExpiry[key] = Date().addingTimeInterval(cacheTimeout)
    }
    
    /// Clear all cached leaderboard data
    func clearCache() {
        leaderboardCache.removeAll()
        globalLeaderboardCache.removeAll()
        cacheExpiry.removeAll()
        print("🗑️ Leaderboard cache cleared")
    }
    
    /// Refresh leaderboard calculations
    func refreshLeaderboards(communityId: String) async throws {
        print("🔄 Refreshing leaderboard for community: \(communityId)")
        
        // Clear cache for this community
        let keysToRemove = cacheExpiry.keys.filter { $0.contains(communityId) }
        for key in keysToRemove {
            leaderboardCache.removeValue(forKey: key)
            cacheExpiry.removeValue(forKey: key)
        }
        
        // Force reload
        _ = try await getLeaderboard(communityId: communityId, category: .consistencyMasters)
    }
    
    /// Refresh global leaderboards
    func refreshGlobalLeaderboards() async throws {
        print("🔄 Refreshing global leaderboards")
        
        // Clear global cache
        let globalKeys = cacheExpiry.keys.filter { $0.contains("global") }
        for key in globalKeys {
            leaderboardCache.removeValue(forKey: key)
            cacheExpiry.removeValue(forKey: key)
        }
        globalLeaderboardCache.removeAll()
        
        // Force reload
        _ = try await getGlobalLeaderboard(category: .consistencyMasters)
    }
}

// MARK: - Supporting Types

enum LeaderboardTimeframe: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case allTime = "allTime"
    
    var displayName: String {
        switch self {
        case .daily: return "Today"
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .quarterly: return "This Quarter"
        case .yearly: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

struct CommunityMember {
    let userId: String
    let username: String
}

enum LeaderboardError: Error, LocalizedError {
    case noCurrentUser
    case invalidCommunityId
    case calculationFailed
    case cacheError
    
    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "No current user found"
        case .invalidCommunityId:
            return "Invalid community ID"
        case .calculationFailed:
            return "Failed to calculate leaderboard stats"
        case .cacheError:
            return "Cache operation failed"
        }
    }
}
