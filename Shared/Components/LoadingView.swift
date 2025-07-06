// File: Shared/Components/LoadingView.swift
// Simplified Loading View

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 10)
        }
    }
}

#Preview {
    LoadingView()
}
