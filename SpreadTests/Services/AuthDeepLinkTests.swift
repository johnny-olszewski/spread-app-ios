import Foundation
import Testing
@testable import Spread

@MainActor
struct AuthDeepLinkTests {

    // MARK: - handle(url:) - Fragment Parameters

    /// Conditions: URL has `type=signup` in the fragment (typical Supabase email confirmation URL).
    /// Expected: `handle(url:)` returns `.emailConfirmed`.
    @Test func handleSignupTypeInFragmentReturnsEmailConfirmed() async throws {
        let service = MockAuthService()
        let url = URL(string: "spread://auth/callback#access_token=abc&type=signup")!

        let result = try await service.handle(url: url)

        guard case .emailConfirmed = result else {
            #expect(Bool(false), "Expected .emailConfirmed, got \(result)")
            return
        }
    }

    /// Conditions: URL has `type=recovery` in the fragment (typical Supabase password reset URL).
    /// Expected: `handle(url:)` returns `.recoverySession`.
    @Test func handleRecoveryTypeInFragmentReturnsRecoverySession() async throws {
        let service = MockAuthService()
        let url = URL(string: "spread://auth/callback#access_token=abc&type=recovery")!

        let result = try await service.handle(url: url)

        guard case .recoverySession = result else {
            #expect(Bool(false), "Expected .recoverySession, got \(result)")
            return
        }
    }

    // MARK: - handle(url:) - Query Parameters

    /// Conditions: URL has `type=signup` as a query parameter (not fragment).
    /// Expected: `handle(url:)` returns `.emailConfirmed`.
    @Test func handleSignupTypeInQueryReturnsEmailConfirmed() async throws {
        let service = MockAuthService()
        let url = URL(string: "spread://auth/callback?type=signup&access_token=abc")!

        let result = try await service.handle(url: url)

        guard case .emailConfirmed = result else {
            #expect(Bool(false), "Expected .emailConfirmed, got \(result)")
            return
        }
    }

    // MARK: - Protocol Conformance

    /// Conditions: MockAuthService is constructed and assigned to an `any AuthService` variable.
    /// Expected: Compiles, confirming MockAuthService satisfies the full protocol.
    @Test func mockAuthServiceSatisfiesProtocol() {
        let _: any AuthService = MockAuthService()
    }
}
