import SwiftUI

/// A sheet for creating a new account with email and password.
///
/// Validates email format, password length, and password confirmation
/// before enabling the Create Account button. Shows inline validation
/// errors and server-side error messages.
///
/// After a successful sign-up, transitions to a confirmation state that
/// prompts the user to verify their email. The form does not dismiss —
/// the user can resend the verification email or tap Done to close.
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

    /// Set after a successful sign-up to show the email confirmation state.
    @State private var submittedEmail: String?

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
                if let submitted = submittedEmail {
                    confirmationSection(email: submitted)
                    resendSection(email: submitted)
                } else {
                    fieldsSection
                    validationErrorsSection
                    serverErrorSection
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if submittedEmail != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        createAccountButton
                    }
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

    // MARK: - Form Sections

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

    // MARK: - Confirmation Sections

    private func confirmationSection(email: String) -> some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check Your Email")
                        .fontWeight(.medium)
                    Text("We sent a verification link to \(email). Tap it to confirm your account.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "envelope.badge.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func resendSection(email: String) -> some View {
        Section {
            Button("Resend Email") {
                Task {
                    try? await authManager.resendVerification(email: email)
                }
            }
            if let errorMessage = authManager.errorMessage {
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
                do {
                    try await authManager.signUp(email: email, password: password)
                    submittedEmail = email
                } catch {
                    // Error shown via authManager.errorMessage
                }
            }
        }
        .disabled(!isFormValid || authManager.isLoading)
    }
}

// MARK: - Previews

#Preview("Empty") {
    SignUpSheet(authManager: .makeForPreview())
}

#Preview("Confirmation State") {
    // Shows the post-signup confirmation layout; submittedEmail is @State private
    // so the confirmation sections are rendered directly here for preview purposes.
    NavigationStack {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check Your Email")
                            .fontWeight(.medium)
                        Text("We sent a verification link to user@example.com. Tap it to confirm your account.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(.green)
                }
            }
            Section {
                Button("Resend Email") {}
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {}
            }
        }
    }
}
