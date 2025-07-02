// MARK: - Updated ArkadTraderApp.swift with Firebase
// File: App/ArkadTraderApp.swift

import SwiftUI
import Firebase

@main
struct ArkadTraderApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FirebaseAuthService.shared)
        }
    }
}

// MARK: - New Firebase Authentication Service
// File: Shared/Services/FirebaseAuthService.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FirebaseAuthService: ObservableObject {
    @Published var currentUser: AppUser?
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
            let newUser = AppUser(
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
    
    // MARK: - Private Methods
    
    private func loadUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            if document.exists,
               let data = document.data(),
               let user = try? AppUser.fromFirestore(data: data, id: uid) {
                
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
    
    private func createUserProfile(user: AppUser) async throws {
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

// MARK: - Updated User Model for Firebase
// File: Shared/Models/AppUser.swift

import Foundation
import FirebaseFirestore

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
    var communityIds: [String]
    
    init(id: String, email: String, username: String, fullName: String) {
        self.id = id
        self.email = email
        self.username = username.lowercased()
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
        self.communityIds = []
    }
    
    // Convert to Firestore data
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
            "updatedAt": Timestamp(date: updatedAt),
            "communityIds": communityIds
        ]
    }
    
    // Create from Firestore data
    static func fromFirestore(data: [String: Any], id: String) throws -> AppUser {
        var user = AppUser(
            id: id,
            email: data["email"] as? String ?? "",
            username: data["username"] as? String ?? "",
            fullName: data["fullName"] as? String ?? ""
        )
        
        user.bio = data["bio"] as? String
        user.profileImageURL = data["profileImageURL"] as? String
        user.followersCount = data["followersCount"] as? Int ?? 0
        user.followingCount = data["followingCount"] as? Int ?? 0
        user.isVerified = data["isVerified"] as? Bool ?? false
        user.totalProfitLoss = data["totalProfitLoss"] as? Double ?? 0.0
        user.winRate = data["winRate"] as? Double ?? 0.0
        user.communityIds = data["communityIds"] as? [String] ?? []
        
        if let tierString = data["subscriptionTier"] as? String {
            user.subscriptionTier = SubscriptionTier(rawValue: tierString) ?? .basic
        }
        
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            user.createdAt = createdAtTimestamp.dateValue()
        }
        
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            user.updatedAt = updatedAtTimestamp.dateValue()
        }
        
        return user
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
