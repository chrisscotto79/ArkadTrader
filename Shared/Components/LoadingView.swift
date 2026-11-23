// File: Shared/Components/LoadingView.swift
// Calm loading indicator: the Arkad mark, a spinner and a short message on a card.

import SwiftUI

struct LoadingView: View {
    var message: String = "Loading…"
    var size: LoadingSize = .medium

    @State private var isBreathing = false

    enum LoadingSize {
        case small, medium, large

        var markSize: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 40
            case .large: return 56
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return DS.Spacing.s
            case .medium: return DS.Spacing.m
            case .large: return DS.Spacing.l
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return DS.Spacing.l
            case .medium: return DS.Spacing.xl
            case .large: return DS.Spacing.xxl
            }
        }
    }

    var body: some View {
        VStack(spacing: size.spacing) {
            ArkadMark(size: size.markSize)
                .scaleEffect(isBreathing ? 1.0 : 0.94)
                .opacity(isBreathing ? 1 : 0.7)

            ProgressView()
                .tint(Color.goldText)

            if !message.isEmpty {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(size.padding)
        .frame(minWidth: 160)
        .cardStyle(padding: 0, radius: DS.Radius.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message.isEmpty ? "Loading" : message)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 32) {
        LoadingView(message: "Loading your data…", size: .small)
        LoadingView(message: "Please wait while we process your request", size: .medium)
        LoadingView(message: "Fetching latest information", size: .large)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .screenBackground()
}
