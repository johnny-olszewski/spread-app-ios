/// The result of handling a Supabase auth deeplink URL.
enum AuthDeepLinkResult: Sendable {
    /// Email confirmed (signup flow). Contains the authenticated user.
    case emailConfirmed(AuthSuccess)
    /// Password recovery session established.
    case recoverySession
}
