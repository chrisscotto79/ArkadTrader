// File: Shared/Extensions/View+Extensions.swift
// Simplified View Extensions

import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func cardStyle() -> some View {
        self
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}
