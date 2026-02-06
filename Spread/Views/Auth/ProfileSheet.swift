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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                accountSection
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
            .onChange(of: authManager.state) { _, newState in
                if !newState.isSignedIn {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            if let email = authManager.userEmail {
                LabeledContent("Email", value: email)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ProfileSheet(authManager: .makeForPreview())
}
