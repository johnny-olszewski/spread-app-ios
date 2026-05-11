import SwiftUI

/// A sheet for setting a new password after following a password-reset deeplink.
///
/// Presented when `AuthDeepLinkCoordinator.isRecoverySession` is `true`.
/// Requires the user to enter and confirm a new password before saving.
/// Interactive dismissal is disabled — the user must explicitly cancel or save.
struct SetNewPasswordSheet: View {

    // MARK: - Dependencies

    /// The auth manager that performs the password update.
    let authManager: AuthManager
    /// The coordinator that owns the recovery session state.
    let coordinator: AuthDeepLinkCoordinator

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
            .navigationTitle("Set New Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        coordinator.clearRecoverySession()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Sections

    private var fieldsSection: some View {
        Section {
            SecureField("New Password", text: $password)
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
                    coordinator.clearRecoverySession()
                } catch {
                    // Error shown via authManager.errorMessage
                }
            }
        }
        .disabled(!isFormValid || authManager.isLoading)
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
    let authManager = AuthManager.makeForPreview()
    let coordinator = AuthDeepLinkCoordinator(
        service: MockAuthService(),
        authManager: authManager
    )
    return SetNewPasswordSheet(authManager: authManager, coordinator: coordinator)
}

#Preview("Loading") {
    // Shows the loading overlay appearance when authManager.isLoading is true.
    NavigationStack {
        Form {
            Section {
                SecureField("New Password", text: .constant(""))
                    .textContentType(.newPassword)
                SecureField("Confirm Password", text: .constant(""))
                    .textContentType(.newPassword)
            }
        }
        .overlay {
            ZStack {
                Color.black.opacity(0.2)
                ProgressView()
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Set New Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {}
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Password") {}.disabled(true)
            }
        }
        .interactiveDismissDisabled(true)
    }
}
