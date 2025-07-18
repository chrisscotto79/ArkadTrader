//
//  EmptyFeedView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/8/25.
//


// File: Core/Home/Views/EmptyFeedView.swift
// Simple Empty Feed components to prevent missing references

import SwiftUI

struct EmptyFeedView: View {
    let onCreatePost: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("Welcome to Your Feed!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Share your trading insights and connect with other traders in the community.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: onCreatePost) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Post")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.arkadBlack)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.arkadGold)
                .cornerRadius(25)
                .shadow(color: .arkadGold.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.vertical, 60)
    }
}

struct EmptyFollowingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Posts from Following")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Follow other traders to see their posts here. Discover traders in the search tab.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {}) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Discover Traders")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.arkadBlack)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.arkadGold)
                .cornerRadius(25)
            }
        }
        .padding(.vertical, 60)
    }
}

#Preview {
    VStack {
        EmptyFeedView {
            print("Create post tapped")
        }
        
        Divider()
        
        EmptyFollowingView()
    }
}