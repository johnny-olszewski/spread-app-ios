import Foundation
import Observation
import Supabase

/// Manages authentication state and operations with Supabase.
///
/// Provides email/password sign-in, sign-out with confirmation,
/// and auth state observation for UI updates.
@Observable
@MainActor
final class AuthManager {

    // MARK: - Auth State

    /// The current authentication state.
    enum AuthState: Equatable {
        /// User is not authenticated.
        case signedOut
        /// User is authenticated.
        case signedIn(User)

        /// Whether the user is currently signed in.
        var isSignedIn: Bool {
            if case .signedIn = self { return true }
            return false
        }

        /// The current user, if signed in.
        var user: User? {
            if case .signedIn(let user) = self { return user }
            return nil
        }
    }

    /// The current auth state.
    private(set) var state: AuthState = .signedOut

    /// Whether an auth operation is in progress.
    private(set) var isLoading = false

    /// The last error message, if any.
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    /// The Supabase client.
    private let client: SupabaseClient

    /// Callback for when sign-out completes (to wipe local data).
    var onSignOut: (() async -> Void)?

    /// Callback for when sign-in completes (to merge local data).
    var onSignIn: ((User) async -> Void)?

    // MARK: - Initialization

    /// Creates an AuthManager with the current Supabase configuration.
    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfiguration.url,
            supabaseKey: SupabaseConfiguration.publishableKey
        )

        // Check initial session
        Task {
            await checkSession()
        }
    }

    /// Creates an AuthManager with a custom Supabase client (for testing).
    init(client: SupabaseClient) {
        self.client = client

        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// Checks for an existing session on startup.
    private func checkSession() async {
        do {
            let session = try await client.auth.session
            state = .signedIn(session.user)
        } catch {
            // No valid session, user is signed out
            state = .signedOut
        }
    }

    // MARK: - Sign In

    /// Signs in with email and password.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Throws: An error if sign-in fails.
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )

            state = .signedIn(session.user)

            // Notify for data merge
            await onSignIn?(session.user)

        } catch let error as AuthError {
            errorMessage = mapAuthError(error)
            throw error
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            throw error
        }
    }

    // MARK: - Sign Out

    /// Signs out the current user.
    ///
    /// This will wipe local data via the `onSignOut` callback.
    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await client.auth.signOut()
            state = .signedOut

            // Notify to wipe local data
            await onSignOut?()

        } catch {
            errorMessage = "Failed to sign out. Please try again."
            throw error
        }
    }

    // MARK: - Error Mapping

    /// Maps Supabase auth errors to user-friendly messages.
    private func mapAuthError(_ error: AuthError) -> String {
        switch error {
        case .api(_, let errorCode, _, _):
            switch errorCode {
            case .invalidCredentials:
                return "Invalid email or password."
            case .userNotFound:
                return "No account found with this email."
            case .sessionExpired, .sessionNotFound:
                return "Session expired. Please sign in again."
            default:
                return "Authentication failed. Please try again."
            }
        default:
            return "Authentication failed. Please try again."
        }
    }

    // MARK: - Helpers

    /// Clears any error message.
    func clearError() {
        errorMessage = nil
    }

    /// The current user's email, if signed in.
    var userEmail: String? {
        state.user?.email
    }
}
