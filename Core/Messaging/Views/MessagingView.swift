
// File: Core/Messaging/Views/MessagingView.swift
// Minimal version to get compilation working

import SwiftUI

struct MessagingView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Messages")
                    .font(.title)
                    .padding()
                
                Text("Messaging functionality coming soon...")
                    .foregroundColor(.gray)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Messages")
        }
    }
}

#Preview {
    MessagingView()
}
