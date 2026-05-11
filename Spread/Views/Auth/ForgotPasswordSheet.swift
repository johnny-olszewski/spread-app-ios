import SwiftUI

/// A sheet for requesting a password reset email.
///
/// Validates email format before enabling the Send Reset Link button.
/// Shows a success message after the reset email is sent.
struct ForgotPasswordSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// The auth manager for handling password reset.
    let authManager: AuthManager

    // MARK: - State

    @State private var email = ""
    @State private var hasEditedEmail = false
    @State private var didSendReset = false

    // MARK: - Computed Validation

    private var emailError: String? {
        guard hasEditedEmail else { return nil }
        return AuthFormValidator.validateEmail(email)
    }

    private var isFormValid: Bool {
        AuthFormValidator.validateEmail(email) == nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                if didSendReset {
                    successSection
                } else {
                    emailSection
                    validationSection
                }
            }
            .overlay {
                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSendReset ? "Done" : "Cancel") {
                        dismiss()
                    }
                }
                if !didSendReset {
                    ToolbarItem(placement: .confirmationAction) {
                        sendButton
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { authManager.errorMessage != nil },
                set: { if !$0 { authManager.clearError() } }
            )) {
                Button("OK") { authManager.clearError() }
            } message: {
                Text(authManager.errorMessage ?? "")
            }
            .onDisappear {
                authManager.clearError()
            }
        }
    }

    // MARK: - Sections

    private var emailSection: some View {
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
        } footer: {
            Text("Enter the email associated with your account and we'll send a password reset link.")
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if let error = emailError {
            Section {
                Text(error)
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
    }

    private var successSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reset Link Sent")
                        .fontWeight(.medium)
                    Text("Check your email at \(email) for a password reset link.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "envelope.badge.fill")
                    .foregroundStyle(.green)
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

    // MARK: - Send Button

    private var sendButton: some View {
        Button("Send") {
            Task {
                do {
                    try await authManager.resetPassword(email: email)
                    didSendReset = true
                } catch {
                    // Error is shown via authManager.errorMessage
                }
            }
        }
        .disabled(!isFormValid || authManager.isLoading)
    }
}

// MARK: - Previews

#Preview("Empty") {
    ForgotPasswordSheet(authManager: .makeForPreview())
}

#Preview("Loading") {
    NavigationStack {
        Form {
            Section {
                TextField("Email", text: .constant(""))
            } footer: {
                Text("Enter the email associated with your account and we'll send a password reset link.")
            }
        }
        .overlay {
            ZStack {
                SpreadTheme.Overlay.dim
                ProgressView()
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {}
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send") {}.disabled(true)
            }
        }
    }
}
