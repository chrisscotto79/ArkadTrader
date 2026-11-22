// File: Shared/Services/FirebaseServices+AuthWrappers.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

// MARK: - FirebaseAuthService Extension

extension FirebaseAuthService {
    
    // MARK: - User Discovery Wrapper Methods
    
    
    func getPopularUsers(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getPopularUsers(limit: limit)
    }
    
    func getRecentUsers(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getRecentUsers(limit: limit)
    }
    
    func getTopTraders(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getTopTraders(limit: limit)
    }
    
    func getHighWinRateTraders(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getHighWinRateTraders(limit: limit)
    }
    
    func getVerifiedUsers(limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getVerifiedUsers(limit: limit)
    }
    
    func searchUsersAdvanced(
        query: String,
        minFollowers: Int? = nil,
        isVerified: Bool? = nil,
        subscriptionTier: SubscriptionTier? = nil,
        limit: Int = 20
    ) async throws -> [User] {
        return try await FirebaseServices.shared.searchUsersAdvanced(
            query: query,
            minFollowers: minFollowers,
            isVerified: isVerified,
            subscriptionTier: subscriptionTier,
            limit: limit
        )
    }
    
    func getSuggestedUsers(for userId: String, limit: Int = 20) async throws -> [User] {
        return try await FirebaseServices.shared.getSuggestedUsers(for: userId, limit: limit)
    }
}
