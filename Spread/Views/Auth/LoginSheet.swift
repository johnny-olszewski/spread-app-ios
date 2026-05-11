import SwiftUI

/// A sheet for signing in with email and password.
///
/// Displays email and password fields with a Sign In button.
/// Shows inline validation errors after first edit, server error
/// messages for failed login attempts, and links to Create Account
/// and Forgot Password flows. Dismisses automatically on successful login.
struct LoginSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// The auth manager for handling sign-in.
    let authManager: AuthManager

    /// Whether the cancel button should be shown.
    let showsCancelButton: Bool

    // MARK: - State

    @State private var email = ""
    @State private var password = ""
    @State private var hasEditedEmail = false
    @State private var hasEditedPassword = false
    @State private var isShowingSignUp = false
    @State private var isShowingForgotPassword = false
    @State private var resentEmail = false

    // MARK: - Computed Validation

    private var emailError: String? {
        guard hasEditedEmail else { return nil }
        return AuthFormValidator.validateEmail(email)
    }

    private var passwordError: String? {
        guard hasEditedPassword else { return nil }
        return AuthFormValidator.validatePassword(password)
    }

    private var isFormValid: Bool {
        AuthFormValidator.validateEmail(email) == nil
            && AuthFormValidator.validatePassword(password) == nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                credentialsSection
                validationSection
                verificationSection
                linksSection
            }
            .overlay {
                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCancelButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    signInButton
                }
            }
            .onChange(of: authManager.state) { _, newState in
                if newState.isSignedIn {
                    dismiss()
                }
            }
            .alert("Error", isPresented: Binding(
                get: { authManager.errorMessage != nil && !authManager.requiresEmailVerification },
                set: { if !$0 { authManager.clearError() } }
            )) {
                Button("OK") { authManager.clearError() }
            } message: {
                Text(authManager.errorMessage ?? "")
            }
            .onDisappear {
                authManager.clearError()
            }
            .sheet(isPresented: $isShowingSignUp) {
                SignUpSheet(authManager: authManager)
            }
            .sheet(isPresented: $isShowingForgotPassword) {
                ForgotPasswordSheet(authManager: authManager)
            }
        }
    }

    // MARK: - Sections

    private var credentialsSection: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: email) { _, _ in
                    hasEditedEmail = true
                    resentEmail = false
                    authManager.clearError()
                }

            PasswordField(placeholder: "Password", text: $password)
                .onChange(of: password) { _, _ in
                    hasEditedPassword = true
                    authManager.clearError()
                }
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        let errors = [emailError, passwordError].compactMap { $0 }
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
    private var verificationSection: some View {
        if authManager.requiresEmailVerification {
            Section {
                if resentEmail {
                    Text("Verification email sent.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.LoginSheet.verificationSentConfirmation
                        )
                } else {
                    Button("Resend verification email") {
                        Task {
                            try? await authManager.resendVerification(email: email)
                            resentEmail = true
                        }
                    }
                    .font(.callout)
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.LoginSheet.resendVerificationButton
                    )
                }
            }
        }
    }

    private var linksSection: some View {
        Section {
            Button("Create Account") {
                isShowingSignUp = true
            }

            Button("Forgot Password?") {
                isShowingForgotPassword = true
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            SpreadTheme.Overlay.dim
            ProgressView()
        }
        .ignoresSafeArea()
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button("Sign In") {
            Task {
                try? await authManager.signIn(email: email, password: password)
            }
        }
        .disabled(!isFormValid || authManager.isLoading)
    }
}

// MARK: - Previews

#Preview("Empty") {
    LoginSheet(authManager: .makeForPreview(), showsCancelButton: true)
}

#Preview("Loading") {
    NavigationStack {
        Form {
            Section {
                TextField("Email", text: .constant(""))
                PasswordField(placeholder: "Password", text: .constant(""))
            }
        }
        .overlay {
            ZStack {
                SpreadTheme.Overlay.dim
                ProgressView()
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Sign In") {}.disabled(true)
            }
        }
    }
}
