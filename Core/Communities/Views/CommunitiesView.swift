// File: Core/Communities/Views/CommunitiesView.swift
// Simple placeholder to avoid compilation errors

import SwiftUI

struct CommunitiesView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.arkadGold.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Communities")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Connect with other traders")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Text("Coming Soon!")
                    .font(.caption)
                    .foregroundColor(.arkadGold)
                    .padding()
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()
            .navigationTitle("Communities")
        }
    }
}

#Preview {
    CommunitiesView()
}
