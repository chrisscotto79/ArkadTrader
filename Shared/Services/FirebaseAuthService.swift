// File: Shared/Services/FirebaseAuthService.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FirebaseAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    static let shared = FirebaseAuthService()
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.loadUserData(uid: user.uid)
                } else {
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await loadUserData(uid: result.user.uid)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func register(email: String, password: String, username: String, fullName: String) async throws {
        isLoading = true
        errorMessage = ""
        
        do {
            // Check if username is available
            let usernameExists = try await checkUsernameExists(username)
            if usernameExists {
                throw AuthError.usernameAlreadyExists
            }
            
            // Create Firebase user
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // Create user document in Firestore
            let user = AppUser(
                id: result.user.uid,
                email: email,
                username: username,
                fullName: fullName
            )
            
            try await saveUserData(user)
            
            await loadUserData(uid: result.user.uid)
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func logout() async {
        do {
            try auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func updateProfile(fullName: String?, bio: String?) async throws {
        guard var user = currentUser else {
            throw AuthError.userNotFound
        }
        
        if let fullName = fullName {
            user.fullName = fullName
        }
        
        if let bio = bio {
            user.bio = bio
        }
        
        user.updatedAt = Date()
        
        try await saveUserData(user)
        currentUser = user
    }
    
    // MARK: - Private Methods
    
    private func loadUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            if document.exists, let data = document.data() {
                let user = try AppUser.fromFirestore(data: data, id: uid)
                currentUser = user
                isAuthenticated = true
            } else {
                // User document doesn't exist, sign out
                try auth.signOut()
                isAuthenticated = false
                currentUser = nil
            }
        } catch {
            print("Error loading user data: \(error.localizedDescription)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    private func saveUserData(_ user: AppUser) async throws {
        try await db.collection("users").document(user.id).setData(user.toFirestore())
    }
    
    private func checkUsernameExists(_ username: String) async throws -> Bool {
        let query = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        
        return !query.documents.isEmpty
    }
}

// MARK: - App User Model for Firebase

struct AppUser: Identifiable, Codable {
    let id: String
    var email: String
    var username: String
    var fullName: String
    var bio: String?
    var profileImageURL: String?
    var followersCount: Int
    var followingCount: Int
    var isVerified: Bool
    var subscriptionTier: SubscriptionTier
    var totalProfitLoss: Double
    var winRate: Double
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String, email: String, username: String, fullName: String) {
        self.id = id
        self.email = email
        self.username = username
        self.fullName = fullName
        self.bio = nil
        self.profileImageURL = nil
        self.followersCount = 0
        self.followingCount = 0
        self.isVerified = false
        self.subscriptionTier = .basic
        self.totalProfitLoss = 0.0
        self.winRate = 0.0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func toFirestore() -> [String: Any] {
        return [
            "email": email,
            "username": username,
            "fullName": fullName,
            "bio": bio as Any,
            "profileImageURL": profileImageURL as Any,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "isVerified": isVerified,
            "subscriptionTier": subscriptionTier.rawValue,
            "totalProfitLoss": totalProfitLoss,
            "winRate": winRate,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
    
    static func fromFirestore(data: [String: Any], id: String) throws -> AppUser {
        guard let email = data["email"] as? String,
              let username = data["username"] as? String,
              let fullName = data["fullName"] as? String,
              let followersCount = data["followersCount"] as? Int,
              let followingCount = data["followingCount"] as? Int,
              let isVerified = data["isVerified"] as? Bool,
              let subscriptionTierString = data["subscriptionTier"] as? String,
              let subscriptionTier = SubscriptionTier(rawValue: subscriptionTierString),
              let totalProfitLoss = data["totalProfitLoss"] as? Double,
              let winRate = data["winRate"] as? Double,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            throw FirestoreError.invalidData
        }
        
        var user = AppUser(id: id, email: email, username: username, fullName: fullName)
        user.bio = data["bio"] as? String
        user.profileImageURL = data["profileImageURL"] as? String
        user.followersCount = followersCount
        user.followingCount = followingCount
        user.isVerified = isVerified
        user.subscriptionTier = subscriptionTier
        user.totalProfitLoss = totalProfitLoss
        user.winRate = winRate
        user.createdAt = createdAtTimestamp.dateValue()
        user.updatedAt = updatedAtTimestamp.dateValue()
        
        return user
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case usernameAlreadyExists
    case userNotFound
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .usernameAlreadyExists:
            return "Username is already taken"
        case .userNotFound:
            return "User not found"
        case .invalidInput:
            return "Invalid input provided"
        }
    }
}

// MARK: - Firestore Errors

enum FirestoreError: LocalizedError {
    case invalidData
    case documentNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .documentNotFound:
            return "Document not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}