// File: Shared/Services/FirebaseServices.swift
// Combined Firebase Services - Simplified

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {
        checkAuth()
    }
    
    // MARK: - Auth Methods
    
    func checkAuth() {
        if let firebaseUser = Auth.auth().currentUser {
            Task {
                await loadUser(uid: firebaseUser.uid)
            }
        }
    }
    
    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let docRef = db.collection("users").document(result.user.uid)
            let snapshot = try await docRef.getDocument()

            if snapshot.exists {
                await loadUser(uid: result.user.uid)
            } else {
                // If no user doc exists, create a basic one
                let user = User(id: result.user.uid, email: email, username: email.components(separatedBy: "@")[0], fullName: "")
                try await docRef.setData(user.toFirestore())
                currentUser = user
                isAuthenticated = true
            }
        } catch {
            print("Login error: \(error.localizedDescription)")
            throw error
        }
    }

    func register(email: String, password: String, username: String, fullName: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let newUser = User(
                id: result.user.uid,
                email: email,
                username: username.lowercased(),
                fullName: fullName
            )

            try await db.collection("users").document(result.user.uid).setData(newUser.toFirestore())

            currentUser = newUser
            isAuthenticated = true
        } catch {
            print("Register error: \(error.localizedDescription)")
            throw error
        }
    }

    func logout() async {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
            removeAllListeners()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func updateProfile(fullName: String?, bio: String?) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: Any] = [:]
        if let fullName = fullName {
            updates["fullName"] = fullName
        }
        if let bio = bio {
            updates["bio"] = bio
        }
        updates["updatedAt"] = Timestamp(date: Date())
        
        try await db.collection("users").document(userId).updateData(updates)
        
        // Update local user
        if var user = currentUser {
            if let fullName = fullName {
                user.fullName = fullName
            }
            if let bio = bio {
                user.bio = bio
            }
            currentUser = user
        }
    }
    
    private func loadUser(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if let data = document.data() {
                currentUser = try User.fromFirestore(data: data, id: uid)
                isAuthenticated = true
            }
        } catch {
            print("Error loading user: \(error)")
            isAuthenticated = false
        }
    }
    
    // MARK: - Trade Methods
    
    
    func addTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func updateTrade(_ trade: Trade) async throws {
        try await db.collection("trades").document(trade.id).setData(trade.toFirestore())
    }
    
    func deleteTrade(tradeId: String) async throws {
        try await db.collection("trades").document(tradeId).delete()
    }
    
    func getUserTrades(userId: String) async throws -> [Trade] {
        let snapshot = try await db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Trade.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func listenToUserTrades(userId: String, completion: @escaping ([Trade]) -> Void) {
        let listener = db.collection("trades")
            .whereField("userId", isEqualTo: userId)
            .order(by: "entryDate", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching trades: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let trades = documents.compactMap { document in
                    try? Trade.fromFirestore(data: document.data(), id: document.documentID)
                }
                
                completion(trades)
            }
        
        listeners.append(listener)
    }
    
    // MARK: - Post Methods
    
    func createPost(_ post: Post) async throws {
        try await db.collection("posts").document(post.id).setData(post.toFirestore())
    }
    
    func getFeedPosts() async throws -> [Post] {
        let snapshot = try await db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Post.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    // MARK: - Community Methods
    
    func createCommunity(_ community: Community) async throws {
        try await db.collection("communities").document(community.id).setData(community.toFirestore())
    }
    
    func getCommunities() async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .order(by: "memberCount", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? Community.fromFirestore(data: document.data(), id: document.documentID)
        }
    }
    
    func joinCommunity(communityId: String, userId: String) async throws {
        // Add user to community members
        try await db.collection("communities").document(communityId).updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ])
        
        // Add community to user's communities
        try await db.collection("users").document(userId).updateData([
            "communityIds": FieldValue.arrayUnion([communityId])
        ])
    }
    
    // MARK: - User Methods
    
    func updateUserStats(userId: String, totalProfitLoss: Double, winRate: Double) async throws {
        try await db.collection("users").document(userId).updateData([
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Clean up
    
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    
}

// Keep the old name for compatibility
typealias FirestoreService = FirebaseAuthService

enum FirestoreError: Error {
    case invalidData
    case userNotFound
    case unauthorized
}
