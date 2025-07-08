// File: Shared/Components/LoadingView.swift
// Simplified Loading View

import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."
    var size: LoadingSize = .medium
    
    enum LoadingSize {
        case small, medium, large
        
        var scale: CGFloat {
            switch self {
            case .small: return 1.0
            case .medium: return 1.5
            case .large: return 2.0
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(size.scale)
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}
#Preview {
    LoadingView()
}
