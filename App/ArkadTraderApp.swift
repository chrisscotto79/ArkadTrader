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

struct AppSplashView: View {
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = -10
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var particlesOpacity: Double = 0.0
    @State private var rippleScale: CGFloat = 0.0
    @State private var backgroundShift: Bool = false
    @State private var progressValue: Double = 0.0
    
    var body: some View {
        ZStack {
            // Enhanced background with animated gradients
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.arkadDark,
                        Color.arkadDark.opacity(0.9),
                        Color.black.opacity(0.95),
                        Color.black
                    ]),
                    startPoint: backgroundShift ? .topTrailing : .topLeading,
                    endPoint: backgroundShift ? .bottomLeading : .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: backgroundShift)
                
                // Animated particle overlay
                ParticleOverlay()
                    .opacity(particlesOpacity)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo/Brand Section with enhanced animations
                VStack(spacing: 30) {
                    ZStack {
                        // Outer ripple effect
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(
                                    Color.arkadGold.opacity(0.3 - Double(index) * 0.1),
                                    lineWidth: 2
                                )
                                .frame(width: 140 + CGFloat(index * 20), height: 140 + CGFloat(index * 20))
                                .scaleEffect(rippleScale)
                                .opacity(rippleScale > 0.5 ? 1.0 - rippleScale : rippleScale * 2)
                                .animation(
                                    .easeOut(duration: 2.0)
                                    .repeatForever()
                                    .delay(Double(index) * 0.3),
                                    value: isAnimating
                                )
                        }
                        
                        // Main logo container with glow effect
                        ZStack {
                            // Glow background
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.arkadGold.opacity(0.3),
                                            Color.arkadGold.opacity(0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .blur(radius: 20)
                                .scaleEffect(isAnimating ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                            
                            // Inner golden ring
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [
                                            Color.arkadGold,
                                            Color.arkadGold.opacity(0.8),
                                            Color.arkadGold,
                                            Color.arkadGold.opacity(0.6),
                                            Color.arkadGold
                                        ],
                                        center: .center
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(logoRotation * 2))
                            
                            // Logo background
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.arkadDark.opacity(0.8),
                                            Color.black.opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: Color.arkadGold.opacity(0.5), radius: 15)
                            
                            // Arkad Text Logo
                            Text("Arkad")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.arkadGold, .arkadGold.opacity(0.8), .arkadGold],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .opacity(logoOpacity)
                                .shadow(color: .arkadGold.opacity(0.5), radius: 8)
                        }
                        .scaleEffect(logoScale)
                        .rotationEffect(.degrees(logoRotation))
                    }
                    
                    // Enhanced app title with animated letters
                    VStack(spacing: 12) {
                        AnimatedText(text: "ARKAD", delay: 1.2)
                    }
                    .opacity(textOpacity)
                }
                
                Spacer()
                
                // Enhanced loading section
                VStack(spacing: 20) {
                    // Progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Initializing your trading platform...")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(Int(progressValue))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.arkadGold)
                        }
                        
                        ProgressView(value: progressValue / 100.0)
                            .progressViewStyle(CustomProgressStyle())
                            .frame(height: 6)
                    }
                    .opacity(textOpacity)
                    
                    // Enhanced loading dots
                    EnhancedLoadingDots()
                        .opacity(textOpacity)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Version info with subtle animation
                VStack(spacing: 6) {
                    Text("Version 1.0.0")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("© 2025 Arkad")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.arkadGold.opacity(0.7))
                }
                .opacity(textOpacity)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startEnhancedAnimations()
        }
    }
    
    private func startEnhancedAnimations() {
        // Background animation
        withAnimation(.easeInOut(duration: 0.1)) {
            backgroundShift = true
        }
        
        // Logo entrance
        withAnimation(.interpolatingSpring(stiffness: 50, damping: 10).delay(0.3)) {
            logoScale = 1.0
            logoRotation = 0
            logoOpacity = 1.0
        }
        
        // Ripple effect
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            rippleScale = 1.0
        }
        
        // Text fade in
        withAnimation(.easeOut(duration: 1.0).delay(0.8)) {
            textOpacity = 1.0
        }
        
        // Particles
        withAnimation(.easeIn(duration: 1.5).delay(1.0)) {
            particlesOpacity = 1.0
        }
        
        // Continuous animations
        withAnimation(.easeInOut(duration: 2.0).delay(1.2)) {
            isAnimating = true
        }
        
        // Much slower, realistic progress simulation
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            if progressValue < 100 {
                // Much slower progress with realistic variations
                let increment: Double
                switch progressValue {
                case 0..<20:
                    increment = Double.random(in: 0.3...0.6) // Slow start
                case 20..<40:
                    increment = Double.random(in: 0.4...0.8) // Pick up speed
                case 40..<70:
                    increment = Double.random(in: 0.2...0.5) // Steady progress
                case 70..<85:
                    increment = Double.random(in: 0.15...0.35) // Slow down
                case 85..<95:
                    increment = Double.random(in: 0.08...0.2) // Very slow near end
                default:
                    increment = Double.random(in: 0.05...0.15) // Crawl to finish
                }
                
                progressValue += increment
                
                // Ensure it reaches exactly 100%
                if progressValue >= 100 {
                    progressValue = 100
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Animated Text Component
struct AnimatedText: View {
    let text: String
    let delay: Double
    var size: CGFloat = 32
    var weight: Font.Weight = .bold
    
    @State private var animatedText = ""
    @State private var opacity: Double = 0.0
    
    var body: some View {
        Text(animatedText)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundStyle(
                LinearGradient(
                    colors: [.arkadGold, .arkadGold.opacity(0.8), .arkadGold],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(opacity)
            .onAppear {
                animateText()
            }
    }
    
    private func animateText() {
        withAnimation(.easeIn(duration: 0.3).delay(delay)) {
            opacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for (index, character) in text.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    animatedText += String(character)
                }
            }
        }
    }
}

// MARK: - Enhanced Loading Dots
struct EnhancedLoadingDots: View {
    @State private var animating = false
    @State private var currentDot = 0
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.arkadGold,
                                Color.arkadGold.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentDot == index ? 1.5 : 0.7)
                    .opacity(currentDot == index ? 1.0 : 0.4)
                    .shadow(color: Color.arkadGold.opacity(0.6), radius: currentDot == index ? 4 : 0)
                    .animation(.easeInOut(duration: 0.3), value: currentDot)
            }
        }
        .onAppear {
            startDotAnimation()
        }
    }
    
    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            currentDot = (currentDot + 1) % 5
        }
    }
}

// MARK: - Custom Progress Style
struct CustomProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.1))
            
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.arkadGold, .arkadGold.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(x: configuration.fractionCompleted ?? 0, y: 1, anchor: .leading)
                .shadow(color: Color.arkadGold.opacity(0.5), radius: 2)
        }
    }
}

// MARK: - Particle Overlay
struct ParticleOverlay: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.arkadGold.opacity(0.3))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<20).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.4)
            )
        }
    }
    
    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            for index in particles.indices {
                particles[index].position.y -= CGFloat.random(in: 0.5...1.5)
                particles[index].opacity *= 0.998
                
                if particles[index].position.y < -10 || particles[index].opacity < 0.01 {
                    particles[index] = Particle(
                        position: CGPoint(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: UIScreen.main.bounds.height + 10
                        ),
                        size: CGFloat.random(in: 2...6),
                        opacity: Double.random(in: 0.1...0.4)
                    )
                }
            }
        }
    }
}

// MARK: - Particle Model
struct Particle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}
