// File: Core/Profile/Views/EditProfileView.swift

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName: String = ""
    @State private var bio: String = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
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
            .alert("Success", isPresented: $showAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
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
        
        Task {
            do {
                try await authViewModel.updateProfile(
                    fullName: fullName,
                    bio: bio
                )
                
                alertMessage = "Profile updated successfully!"
                showAlert = true
            } catch {
                alertMessage = "Failed to update profile"
                showAlert = true
            }
            
            isLoading = false
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
