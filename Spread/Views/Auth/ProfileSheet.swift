import SwiftUI

/// A sheet showing the user's profile with sign out option.
///
/// Displays the user's email and provides a Sign Out button
/// in the toolbar. Sign out requires confirmation via alert.
struct ProfileSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// The auth manager for handling sign-out.
    let authManager: AuthManager

    // MARK: - State

    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isShowingChangePassword = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                legalSection
                deleteAccountSection
            }
            .overlay {
                if authManager.isLoading {
                    ZStack {
                        SpreadTheme.Overlay.dim
                        ProgressView()
                    }
                    .ignoresSafeArea()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirmation = true
                    }
                    .disabled(authManager.isLoading)
                }
            }
            .confirmationDialog(
                "Delete Account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        try? await authManager.deleteAccount()
                    }
                }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.ProfileSheet.deleteAccountConfirmButton
                )
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all associated data. This cannot be undone.")
            }
            .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authManager.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Signing out will remove all local data from this device. Your data will remain safe in the cloud and will sync again when you sign back in.")
            }
            .alert("Deletion Failed", isPresented: Binding(
                get: { authManager.errorMessage != nil },
                set: { if !$0 { authManager.clearError() } }
            )) {
                Button("OK") { authManager.clearError() }
            } message: {
                Text(authManager.errorMessage ?? "")
            }
            .onChange(of: authManager.state) { _, newState in
                if !newState.isSignedIn {
                    dismiss()
                }
            }
            .sheet(isPresented: $isShowingChangePassword) {
                ChangePasswordSheet(authManager: authManager)
            }
        }
    }

    // MARK: - Sections

    private var legalSection: some View {
        Section("Legal") {
            Link(destination: LegalLinks.termsOfService) {
                HStack {
                    Text("Terms of Service")
                    Spacer()
                    SpreadTheme.Icon.openExternal.sized(SpreadTheme.IconSize.small)
                        .iconTint(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.LegalLinks.profileTermsOfService)

            Link(destination: LegalLinks.privacyPolicy) {
                HStack {
                    Text("Privacy Policy")
                    Spacer()
                    SpreadTheme.Icon.openExternal.sized(SpreadTheme.IconSize.small)
                        .iconTint(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.LegalLinks.profilePrivacyPolicy)
        }
    }

    private var deleteAccountSection: some View {
        Section {
            Button("Delete Account", role: .destructive) {
                showDeleteConfirmation = true
            }
            .disabled(authManager.isLoading)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.ProfileSheet.deleteAccountRow)
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let email = authManager.userEmail {
                LabeledContent("Email", value: email)
            }

            Button("Change Password") {
                isShowingChangePassword = true
            }
            .disabled(authManager.isLoading)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.ProfileSheet.changePasswordRow)
        }
    }
}

// MARK: - Previews

#Preview {
    ProfileSheet(authManager: .makeForPreview())
}
