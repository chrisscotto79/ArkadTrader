// File: Shared/Services/FirebaseServices.swift
// Consolidated Firebase services for ArkadTrader

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Firebase Authentication Service
@MainActor
class FirebaseAuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    static let shared = FirebaseAuthService()
    private let db = Firestore.firestore()
    
    private init() {
        // Listen for authentication state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.loadUserProfile(uid: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadUserProfile(uid: result.user.uid)
        } catch {
            throw AuthError.from(error)
        }
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if username is available
            let usernameExists = try await checkUsernameExists(username)
            if usernameExists {
                throw AuthError.usernameUnavailable
            }
            
            // Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user profile in Firestore
            let newUser = User(
                id: result.user.uid,
                email: email,
                username: username,
                fullName: fullName
            )
            
            try await createUserProfile(user: newUser)
            
            self.currentUser = newUser
            self.isAuthenticated = true
            
        } catch {
            throw AuthError.from(error)
        }
    }
    
    func logout() async {
        do {
            try Auth.auth().signOut()
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        } catch {
            print("Logout error: \(error)")
        }
    }
    
    func updateProfile(fullName: String?, bio: String?) async throws {
        guard let currentUser = currentUser else {
            throw AuthError.userNotFound
        }
        
        var updates: [String: Any] = [:]
        
        if let fullName = fullName {
            updates["fullName"] = fullName
        }
        if let bio = bio {
            updates["bio"] = bio
        }
        
        updates["updatedAt"] = FieldValue.serverTimestamp()
        
        try await db.collection("users").document(currentUser.id).updateData(updates)
        
        // Update local user object
        await loadUserProfile(uid: currentUser.id)
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        // Delete user data from Firestore
        if let currentUser = currentUser {
            try await FirestoreService.shared.deleteUserData(userId: currentUser.id)
        }
        
        // Delete Firebase Auth account
        try await firebaseUser.delete()
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            if document.exists,
               let data = document.data(),
               let user = try? User.fromFirestore(data: data, id: uid) {
                
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            } else {
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        } catch {
            print("Failed to load user profile: \(error)")
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    private func createUserProfile(user: User) async throws {
        let userData = user.toFirestore()
        try await db.collection("users").document(user.id).setData(userData)
    }
    
    private func checkUsernameExists(_ username: String) async throws -> Bool {
        let query = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .getDocuments()
        
        return !query.documents.isEmpty
    }
}

// MARK: - Firestore Service
@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Listener Management
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - User Operations
    
    func deleteUserData(userId: String) async throws {
        let batch = db.batch()
        
        // Delete user's trades
        let tradesSnapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        for document in tradesSnapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        // Delete user profile
        batch.deleteDocument(db.collection("users").document(userId))
        
        try await batch.commit()
    }
    
    // MARK: - Trades Operations
    
    func addTrade(_ trade: Trade) async throws {
        let tradeData = trade.toFirestore()
        try await db.collection("trades").document(trade.id.uuidString).setData(tradeData)
    }
    
    func updateTrade(_ trade: Trade) async throws {
        let tradeData = trade.toFirestore()
        try await db.collection("trades").document(trade.id.uuidString).updateData(tradeData)
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await db.collection("trades").document(tradeId).delete()
    }
    
    func getUserTrades(userId: String) async throws -> [Trade] {
        let snapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func listenToUserTrades(userId: String, completion: @escaping ([Trade]) -> Void) {
        let listener = db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to trades: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let trades = documents.compactMap { document -> Trade? in
                    try? Trade.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(trades)
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Portfolio Operations
    
    func updateUserStats(userId: String, totalProfitLoss: Double, winRate: Double) async throws {
        let updates: [String: Any] = [
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).updateData(updates)
    }
    
    // MARK: - Community Operations
    
    func createCommunity(_ community: Community) async throws {
        let communityData = community.toFirestore()
        try await db.collection("communities").document(community.id).setData(communityData)
    }
    
    func getCommunities() async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .order(by: "memberCount", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        let membershipId = "\(communityId)__\(userId)"
        let membershipData: [String: Any] = [
            "communityId": communityId,
            "userId": userId,
            "role": "member",
            "joinedAt": FieldValue.serverTimestamp(),
            "contributionScore": 0
        ]
        
        try await db.collection("communityMembers").document(membershipId).setData(membershipData)
        
        // Update community member count
        try await db.collection("communities").document(communityId).updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ])
        
        // Add community to user's list
        try await db.collection("users").document(userId).updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ])
    }
    
    func leaveCommunity(communityId: String, userId: String) async throws {
        let membershipId = "\(communityId)__\(userId)"
        
        try await db.collection("communityMembers").document(membershipId).delete()
        
        // Update community member count
        try await db.collection("communities").document(communityId).updateData([
            "memberCount": FieldValue.increment(Int64(-1))
        ])
        
        // Remove community from user's list
        try await db.collection("users").document(userId).updateData([
            "communityIds": FieldValue.arrayRemove([communityId])
        ])
    }
    
    // MARK: - Posts Operations
    
    func createPost(_ post: Post) async throws {
        let postData = post.toFirestore()
        try await db.collection("posts").document(post.id.uuidString).setData(postData)
    }
    
    func getFeedPosts(communityId: String? = nil) async throws -> [Post] {
        var query = db.collection("posts").order(by: "createdAt", descending: true)
        
        if let communityId = communityId {
            query = query.whereField("communityId", isEqualTo: communityId)
        }
        
        let snapshot = try await query.limit(to: 50).getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Social Operations
    
    func followUser(followerId: String, followingId: String) async throws {
        let followingDocId = "\(followerId)_\(followingId)"
        let followingData: [String: Any] = [
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("following").document(followingDocId).setData(followingData)
        
        // Update counts
        try await db.collection("users").document(followerId).updateData([
            "followingCount": FieldValue.increment(Int64(1))
        ])
        
        try await db.collection("users").document(followingId).updateData([
            "followersCount": FieldValue.increment(Int64(1))
        ])
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws {
        let followingDocId = "\(followerId)_\(followingId)"
        
        try await db.collection("following").document(followingDocId).delete()
        
        // Update counts
        try await db.collection("users").document(followerId).updateData([
            "followingCount": FieldValue.increment(Int64(-1))
        ])
        
        try await db.collection("users").document(followingId).updateData([
            "followersCount": FieldValue.increment(Int64(-1))
        ])
    }
}

// MARK: - Enhanced Auth Errors
enum AuthError: Error, LocalizedError {
    case userNotFound
    case invalidCredentials
    case networkError
    case usernameUnavailable
    case weakPassword
    case emailAlreadyInUse
    case invalidEmail
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User account not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please check your connection."
        case .usernameUnavailable:
            return "Username is already taken"
        case .weakPassword:
            return "Password should be at least 6 characters"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .unknown(let message):
            return message
        }
    }
    
    static func from(_ error: Error) -> AuthError {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .userNotFound:
                return .userNotFound
            case .wrongPassword, .invalidCredential:
                return .invalidCredentials
            case .networkError:
                return .networkError
            case .weakPassword:
                return .weakPassword
            case .emailAlreadyInUse:
                return .emailAlreadyInUse
            case .invalidEmail:
                return .invalidEmail
            default:
                return .unknown(error.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Firestore Errors
enum FirestoreError: Error, LocalizedError {
    case invalidData
    case userNotAuthenticated
    case permissionDenied
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .permissionDenied:
            return "Permission denied"
        case .networkError:
            return "Network error"
        }
    }
}
