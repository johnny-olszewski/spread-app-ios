import struct Auth.User
import Testing
@testable import Spread

@MainActor
struct MockAuthServiceTests {

    /// Conditions: Localhost auth service checks for a session on launch.
    /// Expected: A mock user session is returned so localhost opens directly into the app.
    @Test func checkSessionReturnsMockUser() async {
        let service = MockAuthService()

        let result = await service.checkSession()

        #expect(result?.user.email == "localhost@spread.debug")
    }

    /// Conditions: A user signs in with a custom email before the next session check.
    /// Expected: Subsequent session checks reuse that email for debug inspection surfaces.
    @Test func checkSessionReusesSignedInEmail() async throws {
        let service = MockAuthService()
        _ = try await service.signIn(email: "debugger@example.com", password: "password")

        let result = await service.checkSession()

        #expect(result?.user.email == "debugger@example.com")
    }
}
