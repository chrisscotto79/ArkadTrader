// File: Shared/Components/LoadingView.swift
// Enhanced Loading View with Logo and Animations

import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."
    var size: LoadingSize = .medium
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var fadeOpacity: Double = 0.3
    
    enum LoadingSize {
        case small, medium, large
        
        var scale: CGFloat {
            switch self {
            case .small: return 0.8
            case .medium: return 1.0
            case .large: return 1.3
            }
        }
        
        var logoSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            }
        }
        
        var circleSize: CGFloat {
            switch self {
            case .small: return 60
            case .medium: return 80
            case .large: return 100
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: size.circleSize + 20, height: size.circleSize + 20)
                    .scaleEffect(pulseScale)
                    .opacity(fadeOpacity)
                
                // Main animated ring
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size.circleSize, height: size.circleSize)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Inner subtle ring
                Circle()
                    .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                    .frame(width: size.circleSize - 10, height: size.circleSize - 10)
                
                // Logo container with background
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .blue.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: size.logoSize + 16, height: size.logoSize + 16)
                        .shadow(color: .blue.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Arkad Logo
                    Image("arkad_Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.logoSize, height: size.logoSize)
                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                }
            }
            .scaleEffect(size.scale)
            
            // Enhanced message text
            VStack(spacing: 4) {
                Text(message)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                
                // Animated dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
                .opacity(0.7)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.blue.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .blue.opacity(0.08), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
        )
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Rotation animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Logo pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
        
        // Outer ring pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
            fadeOpacity = 0.1
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        LoadingView(message: "Loading your data...", size: .small)
        LoadingView(message: "Please wait while we process your request", size: .medium)
        LoadingView(message: "Fetching latest information", size: .large)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
