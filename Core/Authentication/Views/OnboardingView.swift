//
//  OnboardingView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Authentication/Views/OnboardingView.swift

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.dismiss) var dismiss
    
    let pages = [
        OnboardingPage(
            title: "Welcome to ArkadTrader",
            description: "The social trading platform where Instagram meets Wall Street",
            imageName: "chart.line.uptrend.xyaxis"
        ),
        OnboardingPage(
            title: "Track Your Portfolio",
            description: "Keep track of all your trades and see your performance in real-time",
            imageName: "dollarsign.circle"
        ),
        OnboardingPage(
            title: "Compete & Learn",
            description: "Join leaderboards, follow top traders, and improve your skills",
            imageName: "trophy"
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    dismiss()
                }
            }) {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
}

#Preview {
    OnboardingView()
}
