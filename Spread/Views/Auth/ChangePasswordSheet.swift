import SwiftUI

/// A sheet for changing the signed-in user's password.
///
/// Presents two `PasswordField` rows (new password and confirm-password),
/// validates them, and calls `AuthManager.updatePassword` on save.
/// Dismisses automatically on success. Interactive dismissal is allowed —
/// the user opened this voluntarily and can cancel at any time.
struct ChangePasswordSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// The auth manager that performs the password update.
    let authManager: AuthManager

    // MARK: - State

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var hasEditedPassword = false
    @State private var hasEditedConfirmPassword = false

    // MARK: - Computed Validation

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
        AuthFormValidator.validatePassword(password) == nil
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
                validationSection
                errorSection
            }
            .overlay {
                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
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
            PasswordField(placeholder: "New Password", text: $password, isNewPassword: true)
                .onChange(of: password) { _, _ in
                    hasEditedPassword = true
                    authManager.clearError()
                }

            PasswordField(placeholder: "Confirm Password", text: $confirmPassword, isNewPassword: true)
                .onChange(of: confirmPassword) { _, _ in
                    hasEditedConfirmPassword = true
                    authManager.clearError()
                }
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        let errors = [passwordError, confirmPasswordError].compactMap { $0 }
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
    private var errorSection: some View {
        if let errorMessage = authManager.errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button("Save Password") {
            Task {
                do {
                    try await authManager.updatePassword(newPassword: password)
                    dismiss()
                } catch {
                    // Error shown via authManager.errorMessage
                }
            }
        }
        .disabled(!isFormValid || authManager.isLoading)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.ChangePasswordSheet.saveButton)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
            ProgressView()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Empty") {
    ChangePasswordSheet(authManager: .makeForPreview())
}

#Preview("Loading") {
    NavigationStack {
        Form {
            Section {
                PasswordField(placeholder: "New Password", text: .constant(""), isNewPassword: true)
                PasswordField(placeholder: "Confirm Password", text: .constant(""), isNewPassword: true)
            }
        }
        .overlay {
            ZStack {
                Color.black.opacity(0.2)
                ProgressView()
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {}
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Password") {}.disabled(true)
            }
        }
    }
}
