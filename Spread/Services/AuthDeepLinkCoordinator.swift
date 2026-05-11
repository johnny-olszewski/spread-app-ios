import Foundation
import Observation

/// Routes Supabase auth callback deeplinks to the appropriate in-app flow.
///
/// Handles two deeplink types:
/// - Email confirmation (`type=signup`): signs the user in via `AuthManager`.
/// - Password recovery (`type=recovery`): sets `isRecoverySession` so the app
///   can present `SetNewPasswordSheet`.
@Observable
@MainActor
final class AuthDeepLinkCoordinator {

    // MARK: - State

    /// Whether a password recovery session is active.
    ///
    /// Set to `true` when a `type=recovery` deeplink is handled.
    /// Cleared by `clearRecoverySession()` after the user cancels or saves a new password.
    private(set) var isRecoverySession = false

    // MARK: - Dependencies

    private let service: AuthService
    private let authManager: AuthManager

    // MARK: - Initialization

    /// Creates a coordinator with the required auth dependencies.
    ///
    /// - Parameters:
    ///   - service: The auth service used to exchange the deeplink URL for a session.
    ///   - authManager: The auth manager updated after a successful exchange.
    init(service: AuthService, authManager: AuthManager) {
        self.service = service
        self.authManager = authManager
    }

    // MARK: - Deeplink Handling

    /// Routes a Supabase auth callback URL to the appropriate flow.
    ///
    /// Invalid or expired deeplinks are silently ignored.
    ///
    /// - Parameter url: The deeplink URL delivered via `onOpenURL`.
    func handle(url: URL) async {
        do {
            let result = try await service.handle(url: url)
            switch result {
            case .emailConfirmed(let success):
                await authManager.handleEmailConfirmed(success)
            case .recoverySession:
                isRecoverySession = true
            }
        } catch {
            // Invalid or expired deeplinks are silently ignored.
        }
    }

    // MARK: - Recovery Session

    /// Clears the active recovery session.
    ///
    /// Called by `SetNewPasswordSheet` on cancel or after a successful password update.
    func clearRecoverySession() {
        isRecoverySession = false
    }
}
