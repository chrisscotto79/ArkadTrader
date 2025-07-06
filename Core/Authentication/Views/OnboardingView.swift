// File: Core/Authentication/Views/OnboardingView.swift
// Simplified Onboarding View

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Welcome to ArkadTrader")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("The social trading platform where Instagram meets Wall Street")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Get Started") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
    }
}

#Preview {
    OnboardingView()
}
