// File: Shared/Components/CustomButton.swift
// Full-width button with a built-in loading state, built on the design system's
// button styles (PrimaryButtonStyle / SecondaryButtonStyle).

import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var style: ButtonStyleType = .primary
    var systemImage: String? = nil

    enum ButtonStyleType {
        /// Solid gold call to action
        case primary
        /// Neutral filled button
        case secondary
        /// Hairline capsule, transparent background
        case outline
    }

    var body: some View {
        styled(Button(action: action) { label })
            .disabled(isDisabled || isLoading)
            .accessibilityLabel(title)
    }

    private var label: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .tint(style == .primary ? Color.onGold : Color.primary)
            } else {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                Text(title)
            }
        }
    }

    @ViewBuilder
    private func styled<Label: View>(_ button: Button<Label>) -> some View {
        switch style {
        case .primary:
            button.buttonStyle(PrimaryButtonStyle())
        case .secondary:
            button.buttonStyle(SecondaryButtonStyle())
        case .outline:
            button.buttonStyle(OutlineCapsuleButtonStyle())
        }
    }
}

/// Full-width transparent capsule with a hairline border (CustomButton's `.outline`).
struct OutlineCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 12) {
        CustomButton(title: "Sign in", action: {})
        CustomButton(title: "Loading", action: {}, isLoading: true)
        CustomButton(title: "Secondary", action: {}, style: .secondary)
        CustomButton(title: "Outline", action: {}, style: .outline)
        CustomButton(title: "Disabled", action: {}, isDisabled: true)
    }
    .padding()
    .screenBackground()
}
