// File: Core/Profile/Views/EditProfileView.swift
// Edit profile: photo, full name, username and bio.

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
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    photoSection
                    formSection

                    if !getValidationMessage().isEmpty {
                        Label(getValidationMessage(), systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.marketRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    saveButton
                }
                .padding(.horizontal, DS.pageMargin)
                .padding(.top, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xxl)
                .animation(.snappy(duration: 0.2), value: getValidationMessage())
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.goldText)
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.goldText)
                    .disabled(!canSaveProfile || isLoading)
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .alert("Couldn't Save Profile", isPresented: $showValidationError) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
        }
        .interactiveDismissDisabled(isLoading)
        .sheet(isPresented: $showImagePicker) {
            ProfileImagePicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        imageChanged = true
                    }
                }
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(spacing: DS.Spacing.m) {
            Button(action: { showImagePicker = true }) {
                ZStack(alignment: .bottomTrailing) {
                    avatar
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.onGold)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.arkadGold))
                        .overlay(Circle().strokeBorder(Color.appBackground, lineWidth: 3))
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(isLoading)
            .accessibilityLabel("Change profile photo")

            Button("Change photo") { showImagePicker = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .disabled(isLoading)

            if imageChanged {
                Text("Tap Save to upload your new profile photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.2), value: imageChanged)
    }

    @ViewBuilder
    private var avatar: some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ProfileImageView(user: authService.currentUser, size: 112)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            CustomTextField(
                title: "Full name",
                text: $fullName,
                placeholder: "Your name",
                autocapitalization: .words,
                textContentType: .name,
                submitLabel: .next
            )

            CustomTextField(
                title: "Username",
                text: $username,
                placeholder: "username",
                autocapitalization: .never,
                icon: "at",
                textContentType: .username,
                submitLabel: .next,
                autocorrectionDisabled: true
            )
            .onChange(of: username) { _, newValue in
                // Usernames are lowercase
                let lowered = newValue.lowercased()
                if lowered != newValue { username = lowered }
            }

            VStack(alignment: .trailing, spacing: 6) {
                CustomTextField(
                    title: "Bio",
                    text: $bio,
                    placeholder: "Tell other traders about yourself, your style and the markets you follow",
                    multiline: true
                )

                Text("\(bio.count)/150")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(bio.count > 150 ? Color.marketRed : Color.secondary)
            }
        }
        .cardStyle()
    }

    private var saveButton: some View {
        Button {
            Task {
                await saveProfile()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(Color.onGold)
                    Text("Saving…")
                } else {
                    Text("Save changes")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSaveProfile || isLoading)
    }

    // MARK: - Helper Methods

    private func setupInitialValues() {
        if let user = authService.currentUser {
            fullName = user.fullName
            username = user.username
            bio = user.bio ?? ""
        }
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
            // Only what changed is saved; an empty bio removes it
            try await authService.updateProfile(
                fullName: fullName,
                bio: bio,
                username: username,
                profileImage: selectedImage
            )

            // Reset image changed flag
            imageChanged = false
            selectedImage = nil

            dismiss()
        } catch {
            validationMessage = error.localizedDescription
            showValidationError = true
        }

        isLoading = false
    }

    // MARK: - Validation

    private var isValidFullName: Bool {
        let count = fullName.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 2 && count <= 50
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
            return "Username: 3-20 characters, letters, numbers and underscores"
        }
        return ""
    }
}

// MARK: - Custom Text Field Style

/// Rounded `surfaceRaised` text field background for plain `TextField`s.
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.surfaceRaised)
            )
    }
}

#Preview {
    EditProfileView()
        .environmentObject(FirebaseAuthService.shared)
}
