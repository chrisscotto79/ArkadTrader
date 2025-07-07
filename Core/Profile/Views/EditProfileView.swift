// File: Core/Profile/Views/EditProfileView.swift
// Fixed Edit Profile View - No compilation errors

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName = ""
    @State private var bio = ""
    @State private var username = ""
    @State private var showImagePicker = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Picture Section
                    VStack(spacing: 16) {
                        // Profile Picture
                        Button(action: { showImagePicker = true }) {
                            ZStack {
                                // Simple profile avatar
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(getInitials())
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    )
                                
                                // Edit overlay
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Edit")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        Text("Tap to change profile picture")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Full Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Full Name")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if !fullName.isEmpty {
                                    Image(systemName: isValidFullName ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(isValidFullName ? .green : .red)
                                        .font(.caption)
                                }
                            }
                            
                            TextField("Enter your full name", text: $fullName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .autocapitalization(.words)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            fullName.isEmpty ? Color.clear : (isValidFullName ? Color.green : Color.red),
                                            lineWidth: 1
                                        )
                                )
                            
                            if !fullName.isEmpty && !isValidFullName {
                                Text("Name must be between 2 and 50 characters")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Username")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if !username.isEmpty {
                                    Image(systemName: isValidUsername ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(isValidUsername ? .green : .red)
                                        .font(.caption)
                                }
                            }
                            
                            TextField("Enter your username", text: $username)
                                .textFieldStyle(PlainTextFieldStyle())
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            username.isEmpty ? Color.clear : (isValidUsername ? Color.green : Color.red),
                                            lineWidth: 1
                                        )
                                )
                            
                            if !username.isEmpty && !isValidUsername {
                                Text("Username must be 3-20 characters, letters, numbers, and underscores only")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Bio Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bio")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("\(bio.count)/150")
                                    .font(.caption)
                                    .foregroundColor(bio.count > 150 ? .red : .gray)
                            }
                            
                            TextField("Tell people about yourself and your trading style...", text: $bio, axis: .vertical)
                                .textFieldStyle(PlainTextFieldStyle())
                                .lineLimit(4...6)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            bio.isEmpty ? Color.clear : (isValidBio ? Color.green : Color.red),
                                            lineWidth: 1
                                        )
                                )
                            
                            if !bio.isEmpty && !isValidBio {
                                Text("Bio must be 150 characters or less")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Profile Completion Progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Profile Completion")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(Int(profileCompletionPercentage))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: profileCompletionPercentage, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        Text("Complete your profile to unlock more features and improve your visibility to other traders.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Save Button
                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Save Changes")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSaveProfile && !isLoading ? Color.blue : Color.gray)
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
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
            SimpleImagePickerView()
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
            validationMessage = getValidationMessage() ?? "Please check your input"
            showValidationError = true
            return
        }
        
        isLoading = true
        
        do {
            try await authService.updateProfile(
                fullName: fullName.isEmpty ? nil : fullName,
                bio: bio.isEmpty ? nil : bio
            )
            
            dismiss()
        } catch {
            validationMessage = "Failed to save profile: \(error.localizedDescription)"
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
    
    private func getValidationMessage() -> String? {
        if !isValidFullName {
            return "Name must be between 2 and 50 characters"
        }
        if !isValidBio {
            return "Bio must be 150 characters or less"
        }
        if !isValidUsername {
            return "Username must be 3-20 characters, letters, numbers, and underscores only"
        }
        return nil
    }
    
    private var profileCompletionPercentage: Double {
        var completed = 0
        let total = 3
        
        if isValidFullName { completed += 1 }
        if isValidUsername { completed += 1 }
        if !bio.isEmpty { completed += 1 }
        
        return Double(completed) / Double(total) * 100
    }
}

// MARK: - Simple Image Picker (Placeholder)
struct SimpleImagePickerView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Image Picker")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Image picker functionality will be implemented here")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Select from Library") {
                    // Implement image selection
                    dismiss()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                Button("Take Photo") {
                    // Implement camera functionality
                    dismiss()
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
