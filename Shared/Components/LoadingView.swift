//
//  LoadingView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Components/LoadingView.swift

import SwiftUI

struct LoadingView: View {
    @State private var isRotating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isRotating)
                .onAppear {
                    isRotating = true
                }
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
    }
}

struct SmallLoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            .scaleEffect(0.8)
    }
}

#Preview {
    LoadingView()
}
