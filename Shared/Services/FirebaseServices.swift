// File: Shared/Services/FirebaseServices.swift
// Core Firebase service. Feature areas live in FirebaseServices+<Area>.swift.
//
// Firestore uses its default settings (persistent on-device cache). Nothing may change
// `Firestore.settings`: once any call has started the client, changing them throws.

import Foundation
import FirebaseFirestore

// MARK: - Main Service Class

class FirebaseServices {
    static let shared = FirebaseServices()

    /// The one Firestore instance (default settings: persistent cache on the device)
    var db: Firestore { Firestore.firestore() }
    /// Only used by the old direct-message listener (FirebaseServices+Messaging)
    var listeners: [ListenerRegistration] = []

    private init() {}

    // MARK: - Helper Methods

    func createConversationId(between user1: String, and user2: String) -> String {
        let sorted = [user1, user2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }

    // MARK: - Local cache

    private static let clearCacheKey = "arkad.clearFirestoreCacheOnLaunch"

    /// Asks for Firestore's on-device cache to be wiped at the next launch, so the next account
    /// on this phone never sees the previous one's cached data. Called on sign-out.
    ///
    /// The cache can only be cleared before Firestore is first used (or after shutting it down,
    /// which would crash any screen still holding a query from the old instance), so it waits
    /// for the next launch.
    static func requestCacheClearOnNextLaunch() {
        UserDefaults.standard.set(true, forKey: clearCacheKey)
    }

    /// Call once, right after `FirebaseApp.configure()` and before anything touches Firestore.
    /// Clears the cache if a sign-out asked for it. Later Firestore calls queue behind the clear.
    static func clearCacheIfRequested() {
        guard UserDefaults.standard.bool(forKey: clearCacheKey) else { return }
        UserDefaults.standard.removeObject(forKey: clearCacheKey)
        Firestore.firestore().clearPersistence { error in
            #if DEBUG
            if let error { print("Firestore cache not cleared: \(error.localizedDescription)") }
            #endif
        }
    }
}
