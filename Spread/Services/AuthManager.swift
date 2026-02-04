import Foundation
import Observation
import Supabase

/// Manages authentication state and operations with Supabase.
///
/// Provides email/password sign-in, sign-out with confirmation,
/// and auth state observation for UI updates. Auth behavior is
/// controlled by an injected `AuthPolicy` to support debug overrides
/// and localhost mock auth without `#if DEBUG` in core logic.
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

    /// Whether the current user has backup entitlement.
    private(set) var hasBackupEntitlement = false

    /// Whether an auth operation is in progress.
    private(set) var isLoading = false

    /// The last error message, if any.
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    /// The Supabase client (nil for localhost).
    private let client: SupabaseClient?

    /// Policy controlling forced errors and localhost behavior.
    private let policy: AuthPolicy

    /// Callback for when sign-out completes (to wipe local data).
    var onSignOut: (() async -> Void)?

    /// Callback for when sign-in completes (to merge local data).
    var onSignIn: ((User) async -> Void)?

    // MARK: - Initialization

    /// Creates an AuthManager with the current Supabase configuration.
    ///
    /// - Parameter policy: Auth policy for environment behavior (defaults to `DefaultAuthPolicy`).
    init(policy: AuthPolicy = DefaultAuthPolicy()) {
        self.policy = policy

        if policy.isLocalhost {
            self.client = nil
        } else {
            self.client = SupabaseClient(
                supabaseURL: SupabaseConfiguration.url,
                supabaseKey: SupabaseConfiguration.publishableKey
            )
        }

        Task {
            await checkSession()
        }
    }

    /// Creates an AuthManager with a custom Supabase client (for testing).
    init(client: SupabaseClient, policy: AuthPolicy = DefaultAuthPolicy()) {
        self.client = client
        self.policy = policy

        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// Checks for an existing session on startup.
    private func checkSession() async {
        guard !policy.isLocalhost else { return }
        guard let client else { return }

        do {
            let session = try await client.auth.session
            state = .signedIn(session.user)
            hasBackupEntitlement = readBackupEntitlement(from: session.user)
        } catch {
            state = .signedOut
        }
    }

    // MARK: - Sign In

    /// Signs in with email and password.
    ///
    /// Behavior depends on the injected `AuthPolicy`:
    /// - Forced error: throws immediately with a user-facing message.
    /// - Localhost: auto-succeeds with a mock user and backup entitlement.
    /// - Default: performs real Supabase sign-in.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Throws: An error if sign-in fails.
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        if let forced = policy.forcedAuthError() {
            errorMessage = forced.userMessage
            throw ForcedAuthSignInError(forced: forced)
        }

        if policy.isLocalhost {
            let mockUser = makeLocalhostUser(email: email)
            state = .signedIn(mockUser)
            hasBackupEntitlement = true
            await onSignIn?(mockUser)
            return
        }

        guard let client else { return }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )

            state = .signedIn(session.user)
            hasBackupEntitlement = readBackupEntitlement(from: session.user)

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

        if policy.isLocalhost {
            state = .signedOut
            hasBackupEntitlement = false
            await onSignOut?()
            return
        }

        guard let client else { return }

        do {
            try await client.auth.signOut()
            state = .signedOut
            hasBackupEntitlement = false

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

    // MARK: - Entitlement

    /// Reads the backup entitlement flag from the user's app metadata.
    private func readBackupEntitlement(from user: User) -> Bool {
        user.appMetadata["backup_entitled"]?.boolValue ?? false
    }

    // MARK: - Localhost Mock User

    /// Creates a mock User for localhost sign-in.
    private func makeLocalhostUser(email: String) -> User {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "email": "\(email)",
            "appMetadata": {"backup_entitled": true},
            "userMetadata": {},
            "aud": "authenticated",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Safe to force-unwrap: JSON is hardcoded and valid.
        return try! decoder.decode(User.self, from: data)
    }

    // MARK: - Test Support

    #if DEBUG
    /// Configures auth state for testing without hitting Supabase.
    func configureForTesting(state: AuthState, hasBackupEntitlement: Bool = false) {
        self.state = state
        self.hasBackupEntitlement = hasBackupEntitlement
    }
    #endif
}

// MARK: - ForcedAuthSignInError

/// Error thrown when a forced auth error is active.
///
/// Wraps a `ForcedAuthError` so the login sheet can display the user message.
struct ForcedAuthSignInError: Error {
    let forced: ForcedAuthError
}
