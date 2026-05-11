/// An app-level auth state change event emitted by `AuthService.authStateChanges`.
enum AuthChangeEvent: Sendable {
    /// The user was signed out or their account was deleted externally.
    case signedOut
}
