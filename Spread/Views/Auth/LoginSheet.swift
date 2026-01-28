import SwiftUI

/// A sheet for signing in with email and password.
///
/// Displays email and password fields with a Sign In button.
/// Shows error messages for failed login attempts.
/// Dismisses automatically on successful login.
struct LoginSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies

    /// The auth manager for handling sign-in.
    let authManager: AuthManager

    // MARK: - State

    @State private var email = ""
    @State private var password = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                credentialsSection
                errorSection
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
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
            .onDisappear {
                authManager.clearError()
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

            SecureField("Password", text: $password)
                .textContentType(.password)
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

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button("Sign In") {
            Task {
                try? await authManager.signIn(email: email, password: password)
            }
        }
        .disabled(!canSignIn)
    }

    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty && !authManager.isLoading
    }
}

// MARK: - Previews

#Preview("Empty") {
    LoginSheet(authManager: AuthManager())
}
