import struct Auth.User
import Foundation

/// Mock auth service for localhost and testing.
///
/// Always succeeds immediately with a mock user. Useful for:
/// - Local-only development without Supabase
/// - Unit tests requiring predictable auth behavior
@MainActor
final class MockAuthService: AuthService {

    // MARK: - Configuration

    /// Whether the mock user has backup entitlement.
    var mockHasBackupEntitlement = true

    /// The mock user email (updated on sign-in).
    private(set) var currentEmail: String?

    // MARK: - AuthService

    func checkSession() async -> AuthResult? {
        // Mock service has no persistent session
        nil
    }

    func signIn(email: String, password: String) async throws -> AuthResult {
        currentEmail = email
        return AuthResult(
            user: makeLocalhostUser(email: email),
            hasBackupEntitlement: mockHasBackupEntitlement
        )
    }

    func signOut() async throws {
        currentEmail = nil
    }

    // MARK: - Mock User

    /// Creates a mock User for localhost sign-in.
    private func makeLocalhostUser(email: String) -> User {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "email": "\(email)",
            "appMetadata": {"backup_entitled": \(mockHasBackupEntitlement)},
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
