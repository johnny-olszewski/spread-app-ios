import struct Auth.User
import Foundation

/// Mock auth service for localhost and testing.
///
/// Always succeeds immediately with a mock user. Useful for:
/// - Local-only development without Supabase
/// - Unit tests requiring predictable auth behavior
@MainActor
final class MockAuthService: AuthService {
    private static let localhostEmail = "localhost@spread.debug"

    // MARK: - Configuration

    /// The mock user email (updated on sign-in).
    private(set) var currentEmail: String?

    // MARK: - AuthService

    func checkSession() async -> AuthSuccess? {
        let email = currentEmail ?? Self.localhostEmail
        currentEmail = email
        return AuthSuccess(user: makeLocalhostUser(email: email))
    }

    func signIn(email: String, password: String) async throws -> AuthSuccess {
        currentEmail = email
        return AuthSuccess(user: makeLocalhostUser(email: email))
    }

    func signUp(email: String, password: String) async throws -> AuthSuccess {
        currentEmail = email
        return AuthSuccess(user: makeLocalhostUser(email: email))
    }

    func resetPassword(email: String) async throws {
        // No-op for mock
    }

    func signOut() async throws {
        currentEmail = nil
    }

    // MARK: - Mock User

    /// Creates a mock User for localhost sign-in.
    private func makeLocalhostUser(email: String) -> User {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "email": "\(email)",
            "appMetadata": {},
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
}
