//
//  EmptyFeedView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/8/25.
//


// File: Core/Home/Views/EmptyFeedView.swift
// Simple Empty Feed components to prevent missing references

import SwiftUI

struct EmptyFollowingView: View {
    @EnvironmentObject var tabRouter: TabRouter
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("Nothing from people you follow")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Follow other traders to see their posts and public trades here.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button(action: { tabRouter.selected = .search }) {
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
