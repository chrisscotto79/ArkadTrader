//
//  RegisterView.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/17/25.
//

// File: Core/Authentication/Views/RegisterView.swift

// File: Core/Authentication/Views/RegisterView.swift

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $authViewModel.fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Username", text: $authViewModel.username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $authViewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $authViewModel.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Create Account") {
                        Task {
                            await authViewModel.register()
                            if authViewModel.isAuthenticated {
                                dismiss()
                            }
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.arkadGold)
                    .cornerRadius(12)
                    .disabled(authViewModel.isLoading)
                    
                    if authViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal)
                
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
            .alert("Error", isPresented: $authViewModel.showError) {
                Button("OK") { }
            } message: {
                Text(authViewModel.errorMessage)
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
