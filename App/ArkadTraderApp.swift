// File: App/ArkadTraderApp.swift
// Simplified App Entry Point

import SwiftUI
import Firebase

@main
struct ArkadTraderApp: App {
    @StateObject private var authService = FirebaseAuthService.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
