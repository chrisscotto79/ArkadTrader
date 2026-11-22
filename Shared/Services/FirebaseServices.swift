// File: Shared/Services/FirebaseServices.swift
// Core Firebase service. Feature areas live in FirebaseServices+<Area>.swift.

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import FirebaseStorage

// MARK: - Main Service Class

class FirebaseServices {
    static let shared = FirebaseServices()
    let db = Firestore.firestore()
    var listeners: [ListenerRegistration] = []
    
    private init() {
        configureFirestore()
    }
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Configuration
    
    private func configureFirestore() {
        let settings = FirestoreSettings()
        
        // Use persistent cache settings (replaces both isPersistenceEnabled and cacheSizeBytes)
        let cacheSettings = PersistentCacheSettings()
        // Note: PersistentCacheSettings automatically enables persistence and provides generous cache limits
        // If you need to set a specific size limit, use cacheSettings.sizeBytes = yourLimit
        settings.cacheSettings = cacheSettings
        
        db.settings = settings
    }
    
    // MARK: - Helper Methods
    
    func createConversationId(between user1: String, and user2: String) -> String {
        let sorted = [user1, user2].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }
    
    // MARK: - Cleanup
    
    func removeAllListeners() {
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
}
