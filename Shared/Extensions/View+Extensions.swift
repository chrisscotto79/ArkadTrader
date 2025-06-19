//
//  View+Extensions.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Extensions/View+Extensions.swift

import SwiftUI

extension View {
    // MARK: - Conditional View Modifiers
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    // MARK: - Navigation
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Styling Helpers
    func cardStyle() -> some View {
        self
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    func profitLossColor(for value: Double) -> Color {
        if value > 0 {
            return .profit
        } else if value < 0 {
            return .loss
        } else {
            return .neutral
        }
    }
    
    // MARK: - Loading State
    @ViewBuilder
    func withLoadingOverlay(_ isLoading: Bool) -> some View {
        self
            .overlay(
                Group {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            )
                    }
                }
            )
    }
}
