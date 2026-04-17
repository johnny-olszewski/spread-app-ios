import Foundation
import Observation

/// Coordinates auth lifecycle events with sync and local data management.
///
/// Handles sign-in (start sync), sign-out (wipe + reset), and auto-sync
/// lifecycle. Sync eligibility is based on authenticated session only.
@Observable
@MainActor
final class AuthLifecycleCoordinator {

    // MARK: - Dependencies

    private let authManager: AuthManager
    private let syncEngine: SyncEngine
    private let journalManager: JournalManager

    // MARK: - Private State

    private var didStartAutoSync = false

    // MARK: - Initialization

    /// Creates a coordinator with the required dependencies.
    ///
    /// - Parameters:
    ///   - authManager: The auth manager to observe auth state.
    ///   - syncEngine: The sync engine to start/stop and trigger syncs.
    ///   - journalManager: The journal manager for local data wipe on sign-out.
    init(
        authManager: AuthManager,
        syncEngine: SyncEngine,
        journalManager: JournalManager
    ) {
        self.authManager = authManager
        self.syncEngine = syncEngine
        self.journalManager = journalManager
    }

    // MARK: - Auth Callbacks

    /// Wires `onSignIn` and `onSignOut` callbacks on the auth manager.
    func wireAuthCallbacks() {
        authManager.onSignIn = { [weak self] _ in
            await self?.handleSignedIn()
        }
        authManager.onSignOut = { [weak self] in
            await self?.handleSignedOut()
        }
    }

    /// Handles the initial state when the app launches already signed in.
    func handleInitialAuthState() async {
        guard authManager.state.isSignedIn else { return }
        await handleSignedIn()
    }

    // MARK: - Sign-In

    /// Processes a sign-in event: starts auto-sync and triggers an immediate sync.
    func handleSignedIn() async {
        startAutoSyncIfNeeded()
        await syncEngine.syncNow()
    }

    // MARK: - Sign-Out

    /// Processes a sign-out event: wipes local data and resets sync.
    func handleSignedOut() async {
        await journalManager.clearLocalData()
        syncEngine.resetSyncState()
        stopAutoSyncIfNeeded()
    }

    // MARK: - Auto-Sync Lifecycle

    private func startAutoSyncIfNeeded() {
        guard !didStartAutoSync else { return }
        syncEngine.startAutoSync()
        didStartAutoSync = true
    }

    private func stopAutoSyncIfNeeded() {
        guard didStartAutoSync else { return }
        syncEngine.stopAutoSync()
        didStartAutoSync = false
    }
}
