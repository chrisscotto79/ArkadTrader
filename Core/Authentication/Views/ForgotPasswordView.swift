// File: Core/Authentication/Views/ForgotPasswordView.swift
// Simplified Forgot Password View

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal)
                
                Button("Send Reset Link") {
                    sendResetEmail()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(email.isEmpty)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Password reset email sent!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func sendResetEmail() {
        Task {
            do {
                try await authService.resetPassword(email: email)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(FirebaseAuthService.shared)
}
