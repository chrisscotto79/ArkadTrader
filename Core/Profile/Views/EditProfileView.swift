//
//  EditProfileView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

//
//  EditProfileView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Full Name", text: $fullName)
                    
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authViewModel.currentUser?.email ?? "")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Username")
                        Spacer()
                        Text("@\(authViewModel.currentUser?.username ?? "")")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadCurrentUser()
            }
        }
    }
    
    private func loadCurrentUser() {
        if let user = authViewModel.currentUser {
            fullName = user.fullName
            bio = user.bio ?? ""
        }
    }
    
    private func saveProfile() {
        isLoading = true
        
        // Simulate save delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Update user profile logic would go here
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
