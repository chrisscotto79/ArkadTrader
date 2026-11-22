// File: Shared/Services/FirebaseServices+Moderation.swift

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

extension FirebaseServices {
    // MARK: - Report and Block Methods
    
    func reportPost(postId: String, reportedBy: String, reason: String) async throws {
        let batch = db.batch()
        
        // Add the report
        let report: [String: Any] = [
            "postId": postId,
            "reportedBy": reportedBy,
            "reason": reason,
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        let reportRef = db.collection("reports").document()
        batch.setData(report, forDocument: reportRef)
        
        // Track user's reported posts
        let userReportRef = db.collection("users").document(reportedBy)
            .collection("reportedPosts").document(postId)
        batch.setData([
            "postId": postId,
            "reportedAt": Timestamp(date: Date())
        ], forDocument: userReportRef)
        
        // Increment report count on the post
        let postRef = db.collection("posts").document(postId)
        batch.updateData(["reportCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        
        try await batch.commit()
        
        // Check if post should be auto-hidden (3+ reports)
        try await checkPostReportCount(postId: postId)
    }
    
    func checkPostReportCount(postId: String) async throws {
        let postDoc = try await db.collection("posts").document(postId).getDocument()
        let reportCount = postDoc.data()?["reportCount"] as? Int ?? 0
        
        print("📊 Post \(postId) has \(reportCount) reports")
        
        if reportCount >= 3 {
            // Auto-hide the post
            try await db.collection("posts").document(postId).updateData([
                "isHidden": true,
                "hiddenAt": Timestamp(date: Date()),
                "hiddenReason": "Multiple reports (\(reportCount) reports)"
            ])
            
            print("🚨 Auto-hidden post \(postId) due to \(reportCount) reports")
        }
    }
    
    func reportUser(userId: String, reportedBy: String, reason: String) async throws {
        let report: [String: Any] = [
            "userId": userId,
            "reportedBy": reportedBy,
            "reason": reason,
            "timestamp": Timestamp(date: Date()),
            "status": "pending"
        ]
        
        try await db.collection("reports").document().setData(report)
    }
    
    func blockUser(userId: String, blockedBy: String) async throws {
        let blockRef = db.collection("users").document(blockedBy)
            .collection("blockedUsers").document(userId)
        
        try await blockRef.setData([
            "userId": userId,
            "blockedAt": Timestamp(date: Date())
        ])
    }
    
    func unblockUser(userId: String, unblockedBy: String) async throws {
        try await db.collection("users").document(unblockedBy)
            .collection("blockedUsers").document(userId).delete()
    }
    
    func getUserBlockedUsers(userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(userId)
            .collection("blockedUsers").getDocuments()
        
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    func isUserBlocked(userId: String, by blockedBy: String) async throws -> Bool {
        let document = try await db.collection("users").document(blockedBy)
            .collection("blockedUsers").document(userId).getDocument()
        
        return document.exists
    }
}
