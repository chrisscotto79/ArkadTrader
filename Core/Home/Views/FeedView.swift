// File: Core/Home/Views/FeedView.swift
// Simplified Feed View

import SwiftUI

struct FeedView: View {
    var body: some View {
        SocialFeedView()
    }
}

#Preview {
    FeedView()
        .environmentObject(FirebaseAuthService.shared)
}
