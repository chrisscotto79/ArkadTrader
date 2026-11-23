// File: App/ContentView.swift
// Root view: the sign-in screen when signed out, onboarding for new accounts,
// otherwise the main tabs.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: FirebaseAuthService

    private var needsOnboarding: Bool {
        authService.currentUser?.needsOnboarding == true
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if authService.isAuthenticated {
                if needsOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    TabBarView()
                        .transition(.opacity)
                }
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: needsOnboarding)
        .onChange(of: authService.isAuthenticated) { _, isSignedIn in
            if !isSignedIn {
                TabRouter.shared.reset()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseAuthService.shared)
}
