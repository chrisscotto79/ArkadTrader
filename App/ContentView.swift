// File: App/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabBarView()
                    .environmentObject(authService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .environmentObject(authService)
    }
}

#Preview {
    ContentView()
}
