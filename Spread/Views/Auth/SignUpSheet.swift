import SwiftUI

/// A sheet for creating a new account with email and password.
///
/// Validates email format, password length, and password confirmation
/// before enabling the Create Account button. Shows inline validation
/// errors and server-side error messages.
struct SignUpSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// The auth manager for handling sign-up.
    let authManager: AuthManager

    // MARK: - State

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    /// Tracks whether the user has interacted with each field.
    @State private var hasEditedEmail = false
    @State private var hasEditedPassword = false
    @State private var hasEditedConfirmPassword = false

    // MARK: - Computed Validation

    private var emailError: String? {
        guard hasEditedEmail else { return nil }
        return AuthFormValidator.validateEmail(email)
    }

    private var passwordError: String? {
        guard hasEditedPassword else { return nil }
        return AuthFormValidator.validatePassword(password)
    }

    private var confirmPasswordError: String? {
        guard hasEditedConfirmPassword else { return nil }
        return AuthFormValidator.validatePasswordConfirmation(
            password: password,
            confirmation: confirmPassword
        )
    }

    private var isFormValid: Bool {
        AuthFormValidator.validateEmail(email) == nil
            && AuthFormValidator.validatePassword(password) == nil
            && AuthFormValidator.validatePasswordConfirmation(
                password: password,
                confirmation: confirmPassword
            ) == nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                fieldsSection
                validationErrorsSection
                serverErrorSection
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    createAccountButton
                }
            }
            .onChange(of: authManager.state) { _, newState in
                if newState.isSignedIn {
                    dismiss()
                }
            }
            .onDisappear {
                authManager.clearError()
            }
        }
    }

    // MARK: - Sections

    private var fieldsSection: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: email) { _, _ in
                    hasEditedEmail = true
                    authManager.clearError()
                }

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .onChange(of: password) { _, _ in
                    hasEditedPassword = true
                    authManager.clearError()
                }

            SecureField("Confirm Password", text: $confirmPassword)
                .textContentType(.newPassword)
                .onChange(of: confirmPassword) { _, _ in
                    hasEditedConfirmPassword = true
                    authManager.clearError()
                }
        }
    }

    @ViewBuilder
    private var validationErrorsSection: some View {
        let errors = [emailError, passwordError, confirmPasswordError].compactMap { $0 }
        if !errors.isEmpty {
            Section {
                ForEach(errors, id: \.self) { error in
                    Text(error)
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
        }
    }

    @ViewBuilder
    private var serverErrorSection: some View {
        if let errorMessage = authManager.errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    // MARK: - Create Account Button

    private var createAccountButton: some View {
        Button("Create") {
            Task {
                try? await authManager.signUp(email: email, password: password)
            }
        }
        .disabled(!isFormValid || authManager.isLoading)
    }
}

// MARK: - Previews

#Preview("Empty") {
    SignUpSheet(authManager: .makeForPreview())
}
