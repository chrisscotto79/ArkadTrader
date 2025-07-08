// File: Core/Home/Views/FeedView.swift
// Updated to use MarketNewsFeedView

import SwiftUI

struct FeedView: View {
    var body: some View {
        MarketNewsFeedView()
    }
}

#Preview {
    FeedView()
        .environmentObject(FirebaseAuthService.shared)
}
