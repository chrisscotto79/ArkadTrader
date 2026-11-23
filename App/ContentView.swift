// File: App/ContentView.swift
// Root view: the sign-in screen when signed out, onboarding for new accounts,
// otherwise the main tabs. If the signed-in profile can't be loaded, a retry screen.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: FirebaseAuthService

    private var needsOnboarding: Bool {
        authService.currentUser?.needsOnboarding == true
    }

    private var hasProfile: Bool {
        authService.currentUser != nil
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if authService.isAuthenticated {
                if !hasProfile {
                    ProfileUnavailableView()
                        .transition(.opacity)
                } else if needsOnboarding {
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
        .animation(.easeInOut(duration: 0.3), value: hasProfile)
        .animation(.easeInOut(duration: 0.4), value: needsOnboarding)
        .onChange(of: authService.isAuthenticated) { _, isSignedIn in
            if !isSignedIn {
                TabRouter.shared.reset()
            }
        }
        .alert(
            "Account Deleted",
            isPresented: Binding(
                get: { authService.accountDeletionNotice != nil && !authService.isAuthenticated },
                set: { if !$0 { authService.accountDeletionNotice = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authService.accountDeletionNotice ?? "")
        }
    }
}

/// Signed in, but the profile didn't load (offline, or the profile is missing).
private struct ProfileUnavailableView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            EmptyStateView(
                systemImage: "person.crop.circle.badge.exclamationmark",
                title: "Couldn't load your profile",
                message: "Check your connection and try again. If this keeps happening, sign out and back in."
            )

            VStack(spacing: DS.Spacing.m) {
                Button {
                    retry()
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView().tint(Color.onGold)
                        } else {
                            Text("Try again")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRetrying)

                Button("Sign out") {
                    Task { await authService.logout() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRetrying)
            }
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func retry() {
        isRetrying = true
        Task {
            await authService.retryLoadingProfile()
            isRetrying = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseAuthService.shared)
}
