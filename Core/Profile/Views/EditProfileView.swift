// File: Core/Profile/Views/EditProfileView.swift
// Updated with Profile Image Upload Support

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName = ""
    @State private var bio = ""
    @State private var username = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var isLoading = false
    @State private var imageChanged = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Picture Section
                    VStack(spacing: 16) {
                        // Profile Picture Button
                        Button(action: { showImagePicker = true }) {
                            ZStack {
                                // Profile image or placeholder
                                Group {
                                    if let selectedImage = selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else if let imageUrl = authService.currentUser?.profileImageUrl,
                                              !imageUrl.isEmpty {
                                        AsyncImage(url: URL(string: imageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.arkadGold.opacity(0.2))
                                                .overlay(
                                                    ProgressView()
                                                        .tint(.arkadGold)
                                                )
                                        }
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.arkadGold.opacity(0.8),
                                                        Color.arkadGold.opacity(0.6)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                Text(getInitials())
                                                    .font(.system(size: 36, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.arkadGold, lineWidth: 4)
                                )
                                .shadow(color: Color.arkadGold.opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                // Edit overlay
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 120, height: 120)
                                
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Edit")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isLoading)
                        
                        if imageChanged {
                            Text("Tap Save to upload your new profile picture")
                                .font(.caption)
                                .foregroundColor(.arkadGold)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Full Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                            
                            TextField("Enter your full name", text: $fullName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Username
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                            
                            TextField("Enter username", text: $username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        // Bio
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bio")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                
                                Spacer()
                                
                                Text("\(bio.count)/150")
                                    .font(.caption)
                                    .foregroundColor(bio.count > 150 ? .red : .gray)
                            }
                            
                            TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                                .textFieldStyle(CustomTextFieldStyle())
                                .lineLimit(3...6)
                        }
                    }
                    
                    // Validation Feedback
                    if !getValidationMessage().isEmpty {
                        Text(getValidationMessage())
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Save Button
                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                                Text("Saving...")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                Text("Save Changes")
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSaveProfile && !isLoading ? Color.arkadGold : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canSaveProfile || isLoading)
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .foregroundColor(.arkadGold)
                    .fontWeight(.semibold)
                    .disabled(!canSaveProfile || isLoading)
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        imageChanged = true
                    }
                }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialValues() {
        if let user = authService.currentUser {
            fullName = user.fullName
            username = user.username
            bio = user.bio ?? ""
        }
    }
    
    private func getInitials() -> String {
        guard let user = authService.currentUser else { return "U" }
        let names = user.fullName.split(separator: " ")
        let first = names.first?.first ?? Character("U")
        let last = names.count > 1 ? names.last?.first : nil
        return String(first) + (last != nil ? String(last!) : "")
    }
    
    @MainActor
    private func saveProfile() async {
        guard canSaveProfile else {
            validationMessage = getValidationMessage()
            showValidationError = true
            return
        }
        
        isLoading = true
        
        do {
            try await authService.updateProfile(
                fullName: fullName.isEmpty ? nil : fullName,
                bio: bio.isEmpty ? nil : bio,
                username: username.isEmpty ? nil : username,
                profileImage: selectedImage // Pass the selected image
            )
            
            // Reset image changed flag
            imageChanged = false
            selectedImage = nil
            
            dismiss()
        } catch {
            validationMessage = "Failed to update profile: \(error.localizedDescription)"
            showValidationError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Validation
    
    private var isValidFullName: Bool {
        return fullName.count >= 2 && fullName.count <= 50
    }
    
    private var isValidBio: Bool {
        return bio.count <= 150
    }
    
    private var isValidUsername: Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username)
    }
    
    private var canSaveProfile: Bool {
        return isValidFullName && isValidBio && isValidUsername
    }
    
    private func getValidationMessage() -> String {
        if !isValidFullName {
            return "Name must be between 2 and 50 characters"
        }
        if !isValidBio {
            return "Bio must be 150 characters or less"
        }
        if !isValidUsername {
            return "Username must be 3-20 characters, letters, numbers, and underscores only"
        }
        return ""
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.arkadGold.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    EditProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
