//
//  ProfileSettingsView.swift
//  ArkadTrader
//
//  Created by chris scotto on 7/12/25.
//


// Create this simple placeholder file: Core/Profile/Views/ProfileSettingsView.swift

import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Profile Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}