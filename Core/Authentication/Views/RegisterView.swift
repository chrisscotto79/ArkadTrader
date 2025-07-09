// File: Core/Authentication/Views/RegisterView.swift
// Enhanced Register View with better UX, validation, and design

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var fullName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var agreeToTerms = false
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var currentStep = 1
    
    @FocusState private var fullNameFieldFocused: Bool
    @FocusState private var usernameFieldFocused: Bool
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    @FocusState private var confirmPasswordFieldFocused: Bool

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.arkadGold.opacity(0.1), Color.white]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header Section
                            headerSection
                                .padding(.top, max(20, geometry.safeAreaInsets.top))
                            
                            // Progress Indicator
                            progressIndicator
                                .padding(.top, 30)
                            
                            // Registration Form
                            registrationFormSection
                                .padding(.top, 30)
                            
                            // Terms and Register Button
                            bottomSection
                                .padding(.top, 30)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(50, geometry.safeAreaInsets.bottom + 20))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.arkadGold)
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
        .alert("Registration Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Join the trading community and start your journey")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...2, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.arkadGold : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(step == currentStep ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    if step < 2 {
                        Rectangle()
                            .fill(step < currentStep ? Color.arkadGold : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
            }
            .frame(width: 100)
            
            Text("Step \(currentStep) of 2")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Registration Form Section
    private var registrationFormSection: some View {
        VStack(spacing: 24) {
            if currentStep == 1 {
                personalInfoStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                accountInfoStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: currentStep)
    }
    
    // MARK: - Step 1: Personal Information
    private var personalInfoStep: some View {
        VStack(spacing: 20) {
            Text("Personal Information")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Full Name Field
            enhancedTextField(
                title: "Full Name",
                text: $fullName,
                placeholder: "Enter your full name",
                icon: "person",
                focused: $fullNameFieldFocused,
                validation: { !fullName.isEmpty && fullName.count >= 2 },
                errorMessage: "Full name must be at least 2 characters",
                keyboardType: .default,
                textContentType: .name,
                submitLabel: .next
            ) {
                usernameFieldFocused = true
            }
            
            // Username Field
            enhancedTextField(
                title: "Username",
                text: $username,
                placeholder: "Choose a username",
                icon: "at",
                focused: $usernameFieldFocused,
                validation: { isValidUsername },
                errorMessage: "Username must be 3-20 characters, letters, numbers, and underscores only",
                keyboardType: .default,
                textContentType: .username,
                submitLabel: .next,

            ) {
                nextStep()
            }
            
            // Navigation Buttons
            HStack {
                Spacer()
                
                Button(action: nextStep) {
                    HStack {
                        Text("Next")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.arkadBlack)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(isStep1Valid ? Color.arkadGold : Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(!isStep1Valid)
            }
        }
    }
    
    // MARK: - Step 2: Account Information
    private var accountInfoStep: some View {
        VStack(spacing: 20) {
            Text("Account Information")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Email Field
            enhancedTextField(
                title: "Email Address",
                text: $email,
                placeholder: "Enter your email",
                icon: "envelope",
                focused: $emailFieldFocused,
                validation: { isValidEmail },
                errorMessage: "Please enter a valid email address",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                submitLabel: .next,
            ) {
                passwordFieldFocused = true
            }
            
            // Password Field
            enhancedSecureField(
                title: "Password",
                text: $password,
                placeholder: "Create a password",
                icon: "lock",
                focused: $passwordFieldFocused,
                isVisible: $isPasswordVisible,
                validation: { isValidPassword },
                errorMessage: "Password must be at least 6 characters with uppercase, lowercase, and number",
                submitLabel: .next
            ) {
                confirmPasswordFieldFocused = true
            }
            
            // Confirm Password Field
            enhancedSecureField(
                title: "Confirm Password",
                text: $confirmPassword,
                placeholder: "Confirm your password",
                icon: "lock.shield",
                focused: $confirmPasswordFieldFocused,
                isVisible: $isConfirmPasswordVisible,
                validation: { password == confirmPassword && !password.isEmpty },
                errorMessage: "Passwords don't match",
                submitLabel: .done
            ) {
                if isFormValid && agreeToTerms {
                    register()
                }
            }
            
            // Navigation Buttons
            HStack {
                Button(action: previousStep) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.arkadGold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.arkadGold.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        VStack(spacing: 20) {
            if currentStep == 2 {
                // Terms and Conditions
                Button(action: { agreeToTerms.toggle() }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                            .foregroundColor(agreeToTerms ? .arkadGold : .gray)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I agree to the Terms of Service and Privacy Policy")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Text("By creating an account, you agree to our terms and conditions.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                }
                
                // Register Button
                Button(action: register) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .arkadBlack))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.arkadBlack)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: canRegister ?
                                             [Color.arkadGold, Color.arkadGold.opacity(0.8)] :
                                             [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: canRegister ? Color.arkadGold.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                    .scaleEffect(canRegister ? 1.0 : 0.98)
                    .animation(.easeInOut(duration: 0.2), value: canRegister)
                }
                .disabled(!canRegister)
            }
        }
    }
    
    // MARK: - Enhanced Text Field
    private func enhancedTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        focused: FocusState<Bool>.Binding,
        validation: @escaping () -> Bool,
        errorMessage: String,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        autocapitalization: TextInputAutocapitalization = .sentences,
        onSubmit: @escaping () -> Void = {}
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(focused.wrappedValue ? .arkadGold : .gray)
                    .font(.title3)
                
                TextField(placeholder, text: text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .focused(focused)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                
                if !text.wrappedValue.isEmpty {
                    Image(systemName: validation() ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(validation() ? .green : .red)
                        .font(.title3)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focused.wrappedValue ? Color.arkadGold : Color.gray.opacity(0.3), lineWidth: focused.wrappedValue ? 2 : 1)
            )
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            
            if !text.wrappedValue.isEmpty && !validation() {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Enhanced Secure Field
    private func enhancedSecureField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        focused: FocusState<Bool>.Binding,
        isVisible: Binding<Bool>,
        validation: @escaping () -> Bool,
        errorMessage: String,
        submitLabel: SubmitLabel = .done,
        onSubmit: @escaping () -> Void = {}
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(focused.wrappedValue ? .arkadGold : .gray)
                    .font(.title3)
                
                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textFieldStyle(PlainTextFieldStyle())
                .focused(focused)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                
                Button(action: { isVisible.wrappedValue.toggle() }) {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                
                if !text.wrappedValue.isEmpty {
                    Image(systemName: validation() ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(validation() ? .green : .red)
                        .font(.title3)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focused.wrappedValue ? Color.arkadGold : Color.gray.opacity(0.3), lineWidth: focused.wrappedValue ? 2 : 1)
            )
            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            
            if !text.wrappedValue.isEmpty && !validation() {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private var isValidUsername: Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username)
    }
    
    private var isValidPassword: Bool {
        // At least 6 characters, one uppercase, one lowercase, one number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{6,}$"
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }
    
    private var isStep1Valid: Bool {
        !fullName.isEmpty && fullName.count >= 2 && isValidUsername
    }
    
    private var isFormValid: Bool {
        isStep1Valid && isValidEmail && isValidPassword && password == confirmPassword
    }
    
    private var canRegister: Bool {
        isFormValid && agreeToTerms && !authService.isLoading
    }
    
    // MARK: - Actions
    private func nextStep() {
        if isStep1Valid {
            withAnimation(.easeInOut(duration: 0.4)) {
                currentStep = 2
            }
            emailFieldFocused = true
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep = 1
        }
        fullNameFieldFocused = true
    }
    
    private func register() {
        hideKeyboard()
        
        Task {
            do {
                try await authService.register(
                    email: email,
                    password: password,
                    username: username,
                    fullName: fullName
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func hideKeyboard() {
        fullNameFieldFocused = false
        usernameFieldFocused = false
        emailFieldFocused = false
        passwordFieldFocused = false
        confirmPasswordFieldFocused = false
    }
}

#Preview {
    RegisterView()
        .environmentObject(FirebaseAuthService.shared)
}
