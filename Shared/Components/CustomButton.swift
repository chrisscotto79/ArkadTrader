// File: Shared/Components/CustomButton.swift
// Simplified Custom Button

import SwiftUI

// MARK: - Enhanced Custom Button (drop-in replacement)
struct CustomButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var style: ButtonStyleType = .primary
    
    enum ButtonStyleType {
        case primary, secondary, outline
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .gray
            case .outline: return .clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .white
            case .outline: return .blue
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(isDisabled ? .gray : style.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Group {
                    if isDisabled {
                        Color.gray.opacity(0.3)
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [style.backgroundColor, style.backgroundColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style == .outline ? (isDisabled ? .gray : .blue) : .clear, lineWidth: 1)
            )
            .scaleEffect(isDisabled ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isDisabled)
        }
        .disabled(isDisabled || isLoading)
    }
}

#Preview {
    VStack {
        CustomButton(title: "Click Me", action: {})
        CustomButton(title: "Loading", action: {}, isLoading: true)
        CustomButton(title: "Disabled", action: {}, isDisabled: true)
    }
    .padding()
}
