// File: Shared/Components/CustomButton.swift
// Simplified Custom Button

import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray : Color.blue)
            .cornerRadius(12)
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
