// File: Shared/Services/FirebaseServices+AuthWrappers.swift

import Foundation

// MARK: - FirebaseAuthService Extension

extension FirebaseAuthService {
    // MARK: - User Discovery

    func getPopularUsers(limit: Int = 20) async throws -> [User] {
        try await FirebaseServices.shared.getPopularUsers(limit: limit)
    }
}
