// File: Shared/Components/CustomTextField.swift
// Simplified Custom TextField

import SwiftUI


// MARK: - Enhanced Custom TextField (drop-in replacement)
struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var icon: String? = nil
    var isValid: Bool = true
    var errorMessage: String? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(isFocused ? .blue : .gray)
                        .font(.title3)
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
                .focused($isFocused)
                
                if !text.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isValid ? .green : .red)
                        .font(.title3)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? .blue : (isValid ? .clear : .red),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            if let errorMessage = errorMessage, !isValid {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
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
