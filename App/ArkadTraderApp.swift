// File: App/ArkadTraderApp.swift
// Keep Firebase integration

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
