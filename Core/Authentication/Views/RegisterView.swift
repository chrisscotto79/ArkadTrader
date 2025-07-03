
// File: Core/Authentication/Views/RegisterView.swift
// Complete RegisterView with Firebase integration

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false
    @State private var errorMessage = ""
    @State private var currentStep = 1
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 20) {
                            HStack {
                                Button("Cancel") {
                                    dismiss()
                                }
                                .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text("Step \(currentStep) of 2")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            // Progress Bar
                            ProgressView(value: Double(currentStep), total: 2.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .arkadGold))
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 12) {
                                Text("Create Account")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text(currentStep == 1 ? "Let's get to know you" : "Set up your account")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.bottom, 40)
                        
                        // Form Content
                        VStack(spacing: 24) {
                            if currentStep == 1 {
                                // Step 1: Personal Information
                                VStack(spacing: 20) {
                                    CustomTextField(
                                        title: "Full Name",
                                        text: $fullName,
                                        placeholder: "Enter your full name"
                                    )
                                    
                                    CustomTextField(
                                        title: "Username",
                                        text: $username,
                                        placeholder: "Choose a username"
                                    )
                                    .onChange(of: username) { _, newValue in
                                        username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    }
                                    
                                    if !username.isEmpty {
                                        HStack {
                                            Image(systemName: usernameValidation.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(usernameValidation.isValid ? .green : .red)
                                            Text(usernameValidation.message)
                                                .font(.caption)
                                                .foregroundColor(usernameValidation.isValid ? .green : .red)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            } else {
                                // Step 2: Account Setup
                                VStack(spacing: 20) {
                                    CustomTextField(
                                        title: "Email",
                                        text: $email,
                                        placeholder: "Enter your email address",
                                        keyboardType: .emailAddress,
                                        autocapitalization: .never
                                    )
                                    
                                    CustomTextField(
                                        title: "Password",
                                        text: $password,
                                        placeholder: "Create a password",
                                        isSecure: true
                                    )
                                    
                                    CustomTextField(
                                        title: "Confirm Password",
                                        text: $confirmPassword,
                                        placeholder: "Confirm your password",
                                        isSecure: true
                                    )
                                    
                                    // Password Requirements
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Password Requirements:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                        
                                        ForEach(passwordRequirements, id: \.requirement) { req in
                                            HStack(spacing: 8) {
                                                Image(systemName: req.isMet ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(req.isMet ? .green : .gray)
                                                    .font(.caption)
                                                
                                                Text(req.requirement)
                                                    .font(.caption)
                                                    .foregroundColor(req.isMet ? .green : .gray)
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    // Terms Agreement
                                    VStack(spacing: 12) {
                                        Button(action: { agreedToTerms.toggle() }) {
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(agreedToTerms ? .arkadGold : .gray)
                                                    .font(.title3)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("I agree to the Terms of Service and Privacy Policy")
                                                        .font(.subheadline)
                                                        .foregroundColor(.primary)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    Text("By creating an account, you agree to our terms and acknowledge our privacy practices.")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            
                            // Error Message
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            if currentStep == 1 {
                                Button("Continue") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentStep = 2
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(isEnabled: isStep1Valid))
                                .disabled(!isStep1Valid)
                            } else {
                                Button(action: createAccount) {
                                    HStack {
                                        if authService.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .arkadBlack))
                                                .scaleEffect(0.9)
                                        } else {
                                            Text("Create Account")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .foregroundColor(.arkadBlack)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(isStep2Valid ? Color.arkadGold : Color.gray.opacity(0.3))
                                    )
                                }
                                .disabled(!isStep2Valid || authService.isLoading)
                                
                                Button("Back") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentStep = 1
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.arkadGold)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isStep1Valid: Bool {
        !fullName.isEmpty &&
        !username.isEmpty &&
        fullName.count >= 2 &&
        usernameValidation.isValid
    }
    
    private var isStep2Valid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        email.contains("@") &&
        password == confirmPassword &&
        passwordRequirements.allSatisfy({ $0.isMet }) &&
        agreedToTerms
    }
    
    private var usernameValidation: (isValid: Bool, message: String) {
        if username.isEmpty {
            return (false, "Username is required")
        } else if username.count < 3 {
            return (false, "Username must be at least 3 characters")
        } else if username.count > 20 {
            return (false, "Username must be less than 20 characters")
        } else if !username.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return (false, "Username can only contain letters, numbers, and underscores")
        } else {
            return (true, "Username is available")
        }
    }
    
    private var passwordRequirements: [(requirement: String, isMet: Bool)] {
        [
            ("At least 6 characters", password.count >= 6),
            ("Contains a number", password.contains { $0.isNumber }),
            ("Contains a letter", password.contains { $0.isLetter }),
            ("Passwords match", !confirmPassword.isEmpty && password == confirmPassword)
        ]
    }
    
    // MARK: - Helper Methods
    
    private func createAccount() {
        hideKeyboard()
        errorMessage = ""
        
        Task {
            do {
                try await authService.register(
                    email: email,
                    password: password,
                    username: username,
                    fullName: fullName
                )
                // Success is handled automatically by the environment object
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
