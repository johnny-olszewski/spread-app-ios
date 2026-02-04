import Testing
@testable import Spread

@MainActor
struct AuthPolicyTests {

    // MARK: - DefaultAuthPolicy

    /// Default policy returns no forced error and is not localhost.
    @Test func defaultPolicyHasNoForcedError() {
        let policy = DefaultAuthPolicy()

        #expect(policy.forcedAuthError() == nil)
        #expect(policy.isLocalhost == false)
    }

    // MARK: - ForcedAuthError

    /// Each forced error case has a non-empty user message.
    @Test func forcedAuthErrorsHaveUserMessages() {
        for error in ForcedAuthError.allCases {
            #expect(!error.userMessage.isEmpty, "Missing user message for \(error)")
        }
    }

    /// Each forced error case has a non-empty display name.
    @Test func forcedAuthErrorsHaveDisplayNames() {
        for error in ForcedAuthError.allCases {
            #expect(!error.displayName.isEmpty, "Missing display name for \(error)")
        }
    }

    /// All five expected error cases are present.
    @Test func forcedAuthErrorHasAllExpectedCases() {
        let cases = ForcedAuthError.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.invalidCredentials))
        #expect(cases.contains(.emailNotConfirmed))
        #expect(cases.contains(.userNotFound))
        #expect(cases.contains(.rateLimited))
        #expect(cases.contains(.networkTimeout))
    }

    /// Invalid credentials error has the expected user message.
    @Test func invalidCredentialsMessage() {
        #expect(ForcedAuthError.invalidCredentials.userMessage == "Invalid email or password.")
    }

    /// Network timeout error has the expected user message.
    @Test func networkTimeoutMessage() {
        #expect(ForcedAuthError.networkTimeout.userMessage == "Network timeout. Please check your connection.")
    }

    // MARK: - Custom AuthPolicy Conformance

    /// A custom policy can return a forced error and report localhost status.
    @Test func customPolicyReturnsForcedError() {
        struct TestPolicy: AuthPolicy {
            func forcedAuthError() -> ForcedAuthError? { .rateLimited }
            var isLocalhost: Bool { true }
        }

        let policy = TestPolicy()
        #expect(policy.forcedAuthError() == .rateLimited)
        #expect(policy.isLocalhost == true)
    }
}
