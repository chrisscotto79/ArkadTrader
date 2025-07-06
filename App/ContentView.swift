// File: App/ContentView.swift
// Simplified Content View

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        if authService.isAuthenticated {
            TabBarView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseAuthService.shared)
}
