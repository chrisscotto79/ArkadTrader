// File: App/ArkadTraderApp.swift
// Enhanced App Entry Point with Loading View

import SwiftUI
import Firebase

@main
struct ArkadTraderApp: App {
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var isLoading = true
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    AppSplashView()
                } else {
                    ContentView()
                        .environmentObject(authService)
                }
            }
            .onAppear {
                initializeApp()
            }
        }
    }
    
    private func initializeApp() {
        Task {
            // Give Firebase time to initialize and check auth state
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Check if user is already authenticated
            await authService.checkAuthState()
            
            // Minimum loading time for smooth UX
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.5)) {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - App Splash View
struct AppSplashView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.arkadDark,
                    Color.arkadDark.opacity(0.8),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Logo/Brand Section
                VStack(spacing: 20) {
                    // Logo placeholder - replace with your actual logo
                    ZStack {
                        Circle()
                            .fill(Color.arkadGold.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.arkadGold.opacity(0.3), radius: 20)
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.arkadGold, Color.arkadGold.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 100, height: 100)
                        
                        Text("A")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.arkadGold)
                    }
                    .scaleEffect(logoScale)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    
                    // App name
                    Text("ARKAD")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.arkadGold)
                        .opacity(textOpacity)
                    
                    Text("TRADER")
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(textOpacity)
                }
                
                // Loading indicator
                VStack(spacing: 16) {
                    LoadingDots()
                    
                    Text("Initializing your trading platform...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                // Version info
                VStack(spacing: 4) {
                    Text("Version 1.0.0")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(textOpacity)
                    
                    Text("© 2025 Arkad Trading")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(textOpacity)
                }
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            textOpacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
            isAnimating = true
        }
    }
}

// MARK: - Loading Dots Animation
struct LoadingDots: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.arkadGold)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    AppSplashView()
}
