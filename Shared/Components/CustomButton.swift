//
//  CustomButton.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Components/CustomButton.swift

import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(style.textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray : style.backgroundColor)
            .cornerRadius(12)
        }
        .disabled(isDisabled || isLoading)
    }
}

extension CustomButton {
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .gray.opacity(0.2)
            case .destructive: return .red
            }
        }
        
        var textColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .white
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomButton(title: "Primary Button", action: {})
        CustomButton(title: "Secondary Button", action: {}, style: .secondary)
        CustomButton(title: "Destructive Button", action: {}, style: .destructive)
        CustomButton(title: "Loading...", action: {}, isLoading: true)
        CustomButton(title: "Disabled Button", action: {}, isDisabled: true)
    }
    .padding()
}
