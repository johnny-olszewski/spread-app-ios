/// Errors that can be forced by debug auth policies.
///
/// Each case maps to a user-facing error message displayed in the login sheet.
/// Defined in non-debug code so `AuthManager` can reference it without `#if DEBUG`.
enum ForcedAuthError: String, CaseIterable, Sendable {
    case invalidCredentials
    case emailNotConfirmed
    case userNotFound
    case rateLimited
    case networkTimeout

    /// User-facing error message for display in the login sheet.
    var userMessage: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailNotConfirmed:
            return "Email not confirmed. Please check your inbox."
        case .userNotFound:
            return "No account found with this email."
        case .rateLimited:
            return "Too many attempts. Please try again later."
        case .networkTimeout:
            return "Network timeout. Please check your connection."
        }
    }

    /// Display name for the Debug menu picker.
    var displayName: String {
        switch self {
        case .invalidCredentials:
            return "Invalid Credentials"
        case .emailNotConfirmed:
            return "Email Not Confirmed"
        case .userNotFound:
            return "User Not Found"
        case .rateLimited:
            return "Rate Limited"
        case .networkTimeout:
            return "Network Timeout"
        }
    }
}

/// Policy that controls auth behavior for different environments.
///
/// Core services inject this protocol to keep debug logic out of production files.
/// `DefaultAuthPolicy` is used in Release builds.
protocol AuthPolicy: Sendable {
    /// Returns an error to throw before hitting Supabase, if any.
    func forcedAuthError() -> ForcedAuthError?

    /// Whether this environment bypasses real auth with a mock user.
    var isLocalhost: Bool { get }
}

/// Default auth policy for Release builds.
///
/// No forced errors, no localhost behavior.
struct DefaultAuthPolicy: AuthPolicy {
    func forcedAuthError() -> ForcedAuthError? { nil }
    var isLocalhost: Bool { false }
}
