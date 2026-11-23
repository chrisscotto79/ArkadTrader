// File: App/ContentView.swift
// Root view: the main tabs when signed in, otherwise the sign-in screen.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: FirebaseAuthService

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if authService.isAuthenticated {
                TabBarView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseAuthService.shared)
}
