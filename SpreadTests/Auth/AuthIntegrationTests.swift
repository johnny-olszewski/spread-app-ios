import Auth
import Foundation
import Supabase
import XCTest
@testable import Spread

/// Integration tests for `AuthManager` against a local Docker Supabase instance.
///
/// These tests require:
/// - Local Supabase running (`./scripts/local-supabase.sh start`)
/// - `supabase/local/test.env` present with credentials
///
/// Flows that cannot be automated (link-click email confirmation) are documented in
/// `Documentation/ManualTests.md`.
@MainActor
final class AuthIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var configuration: LocalSupabaseTestConfiguration!
    private var admin: LocalSupabaseAdmin!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        guard let config = try LocalSupabaseTestConfiguration.loadIfAvailable() else {
            throw XCTSkip("Local Supabase test environment not configured. Run ./scripts/local-supabase.sh reset first.")
        }
        do {
            try await config.assertReachable()
        } catch {
            throw XCTSkip("Local Supabase is not reachable. Start Docker and run ./scripts/local-supabase.sh start/reset.")
        }
        configuration = config
        admin = LocalSupabaseAdmin(configuration: config)
    }

    // MARK: - Helpers

    /// Returns a fresh `AuthManager` backed by a real `SupabaseAuthService` using an anon key client.
    private func makeAuthManager() -> AuthManager {
        let client = configuration.makeAnonClient()
        let service = SupabaseAuthService(client: client)
        return AuthManager(service: service)
    }

    /// Returns a unique test email address to avoid conflicts between test runs.
    private func uniqueEmail(label: String = "test") -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "spread+\(label)-\(timestamp)@example.com"
    }

    // MARK: - Sign-in: Success

    /// Conditions: Valid credentials for the pre-seeded primary test account.
    /// Expected: `AuthManager.state` transitions to `.signedIn` with the matching email.
    func testSignIn_validCredentials_succeeds() async throws {
        let authManager = makeAuthManager()

        try await authManager.signIn(email: configuration.primaryEmail, password: configuration.password)

        XCTAssertTrue(authManager.state.isSignedIn)
        XCTAssertNil(authManager.errorMessage)
    }

    /// Conditions: Valid credentials; state is `.signedIn` after login.
    /// Expected: `state.user?.email` equals the sign-in email (case-insensitive).
    func testSignIn_setsUserEmail() async throws {
        let authManager = makeAuthManager()

        try await authManager.signIn(email: configuration.primaryEmail, password: configuration.password)

        XCTAssertEqual(
            authManager.state.user?.email?.lowercased(),
            configuration.primaryEmail.lowercased()
        )
    }

    // MARK: - Sign-in: Failure

    /// Conditions: Correct email, wrong password.
    /// Expected: `errorMessage` is "Invalid email or password." and state stays `.signedOut`.
    func testSignIn_wrongPassword_setsInvalidCredentialsMessage() async throws {
        let authManager = makeAuthManager()

        try? await authManager.signIn(email: configuration.primaryEmail, password: "wrong-password-xyz")

        XCTAssertFalse(authManager.state.isSignedIn)
        XCTAssertEqual(authManager.errorMessage, "Invalid email or password.")
    }

    // MARK: - Sign-in: Whitespace Trimming

    /// Conditions: Email has leading and trailing whitespace.
    /// Expected: `AuthManager` trims the whitespace before sending, and sign-in succeeds.
    func testSignIn_trimsWhitespace_succeeds() async throws {
        let authManager = makeAuthManager()
        let paddedEmail = "  \(configuration.primaryEmail)  "

        try await authManager.signIn(email: paddedEmail, password: configuration.password)

        XCTAssertTrue(authManager.state.isSignedIn)
    }

    // MARK: - Sign-out

    /// Conditions: User is signed in via valid credentials.
    /// Expected: After `signOut`, `state` returns to `.signedOut`.
    func testSignOut_clearsSession() async throws {
        let authManager = makeAuthManager()
        try await authManager.signIn(email: configuration.primaryEmail, password: configuration.password)
        XCTAssertTrue(authManager.state.isSignedIn)

        try await authManager.signOut()

        XCTAssertFalse(authManager.state.isSignedIn)
    }

    // MARK: - Password Update

    /// Conditions: User is signed in; `updatePassword` is called with a new password.
    /// Expected: The user can sign out and then sign back in with the new password.
    /// The original password is restored afterward to keep the test environment stable.
    func testPasswordUpdate_changesPassword() async throws {
        let newPassword = "Integration-New-Pass-\(Int(Date().timeIntervalSince1970))!"
        let authManager = makeAuthManager()
        try await authManager.signIn(email: configuration.primaryEmail, password: configuration.password)

        try await authManager.updatePassword(newPassword: newPassword)
        try await authManager.signOut()

        // Verify new password works
        let verifyManager = makeAuthManager()
        try await verifyManager.signIn(email: configuration.primaryEmail, password: newPassword)
        XCTAssertTrue(verifyManager.state.isSignedIn)

        // Restore the original password so subsequent tests are not broken
        try await verifyManager.updatePassword(newPassword: configuration.password)
    }

    // MARK: - Sign-up

    /// Conditions: A new unique email is used to sign up.
    /// Expected: `signUp` completes without error but `state` stays `.signedOut`
    /// (email confirmation is required before the session is established).
    func testSignUp_doesNotAutoSignIn() async throws {
        let email = uniqueEmail(label: "signup-nologin")
        let authManager = makeAuthManager()
        var onSignInCalled = false
        authManager.onSignIn = { _ in onSignInCalled = true }

        try await authManager.signUp(email: email, password: configuration.password)

        XCTAssertFalse(authManager.state.isSignedIn)
        XCTAssertFalse(onSignInCalled)
        XCTAssertNil(authManager.errorMessage)

        // Cleanup: admin-delete the unconfirmed user
        if let userEmail = try? await findUserId(for: email) {
            try? await admin.deleteUser(userId: userEmail)
        }
    }

    /// Conditions: A user is created via admin API without email confirmation,
    /// then the app attempts sign-in (which should fail with `emailNotConfirmed`),
    /// then admin confirms the email, and sign-in is attempted again.
    /// Expected: First attempt fails with an "email not confirmed" message;
    /// second attempt succeeds and `state` transitions to `.signedIn`.
    func testSignUp_adminConfirm_thenSignIn_succeeds() async throws {
        let email = uniqueEmail(label: "signup-confirm")
        let password = configuration.password

        // 1. Create user without email confirmation
        let user = try await admin.createUser(email: email, password: password, emailConfirm: false)

        defer {
            Task { try? await admin.deleteUser(userId: user.id) }
        }

        // 2. First sign-in attempt should fail: email not confirmed
        let authManager = makeAuthManager()
        try? await authManager.signIn(email: email, password: password)
        XCTAssertFalse(authManager.state.isSignedIn)
        XCTAssertEqual(
            authManager.errorMessage,
            "Please verify your email first. Check your inbox.",
            "Expected email-not-confirmed message before admin confirms"
        )

        // 3. Admin confirms the email
        try await admin.confirmUserEmail(userId: user.id)

        // 4. Second sign-in attempt should succeed
        try await authManager.signIn(email: email, password: password)
        XCTAssertTrue(authManager.state.isSignedIn)
        XCTAssertNil(authManager.errorMessage)
    }

    // MARK: - Delete Account

    /// Conditions: A temporary user is created via admin, signs in, and calls `deleteAccount()`.
    /// Expected: `state` transitions to `.signedOut` and admin `listUsers` no longer contains the user.
    func testDeleteAccount_removesUserAndSignsOut() async throws {
        let email = uniqueEmail(label: "delete-acct")
        let user = try await admin.createUser(email: email, password: configuration.password, emailConfirm: true)

        let authManager = makeAuthManager()
        try await authManager.signIn(email: email, password: configuration.password)
        XCTAssertTrue(authManager.state.isSignedIn)

        try await authManager.deleteAccount()

        XCTAssertFalse(authManager.state.isSignedIn)

        // Verify the user no longer exists in Supabase.
        let adminClient = configuration.makeServiceRoleClient()
        let users = try await adminClient.auth.admin.listUsers()
        let stillExists = users.users.contains { $0.id == user.id }
        XCTAssertFalse(stillExists, "Deleted user should not appear in admin listUsers")
    }

    // MARK: - Resend Verification: requiresEmailVerification state

    /// Conditions: Admin creates a user without email confirmation.
    /// A sign-in attempt is made before the user confirms their email.
    /// Expected: `AuthManager.requiresEmailVerification` is `true` after the failed attempt.
    func testSignIn_unconfirmedEmail_setsRequiresEmailVerification() async throws {
        let email = uniqueEmail(label: "unconfirmed-verify")
        let user = try await admin.createUser(email: email, password: configuration.password, emailConfirm: false)

        defer {
            Task { try? await admin.deleteUser(userId: user.id) }
        }

        let authManager = makeAuthManager()
        try? await authManager.signIn(email: email, password: configuration.password)

        XCTAssertTrue(authManager.requiresEmailVerification)
        XCTAssertFalse(authManager.state.isSignedIn)
    }

    // MARK: - Private Helpers

    /// Looks up the UUID of a user by email via the admin `listUsers` API.
    private func findUserId(for email: String) async throws -> UUID? {
        let adminClient = configuration.makeServiceRoleClient()
        let response = try await adminClient.auth.admin.listUsers()
        return response.users.first { $0.email?.lowercased() == email.lowercased() }?.id
    }
}
