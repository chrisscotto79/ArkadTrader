//
//  ForgotPasswordView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Core/Authentication/Views/ForgotPasswordView.swift
//
//  ForgotPasswordView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
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
                    sendResetLink()
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Link Sent", isPresented: $showAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func sendResetLink() {
        // Simulate sending reset link
        alertMessage = "If an account with email \(email) exists, you will receive a password reset link shortly."
        showAlert = true
    }
}

#Preview {
    ForgotPasswordView()
}
