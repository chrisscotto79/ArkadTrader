//
//  CustomTextField.swift
//  ArkadTrader
//
//  Created by chris scotto on 6/18/25.
//

// File: Shared/Components/CustomTextField.swift

import SwiftUI

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder.isEmpty ? title : placeholder, text: $text)
                } else {
                    TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomTextField(title: "Email", text: .constant(""), placeholder: "Enter your email", keyboardType: .emailAddress, autocapitalization: .never)
        
        CustomTextField(title: "Password", text: .constant(""), placeholder: "Enter your password", isSecure: true)
        
        CustomTextField(title: "Full Name", text: .constant("John Doe"))
        
        CustomTextField(title: "", text: .constant(""), placeholder: "Search...")
    }
    .padding()
}
