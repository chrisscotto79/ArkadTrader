// File: Shared/Components/CustomTextField.swift
// Simplified Custom TextField

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
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomTextField(title: "Email", text: .constant(""), placeholder: "Enter your email")
        CustomTextField(title: "Password", text: .constant(""), isSecure: true)
    }
    .padding()
}
