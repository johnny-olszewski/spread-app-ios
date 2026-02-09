import Foundation
import Observation

/// Coordinates the environment switching flow.
///
/// Handles the multi-step process of switching data environments:
/// 1. Wait for running sync to complete
/// 2. Attempt final sync push
/// 3. Warn if sync failed with pending outbox data
/// 4. Sign out and wipe local store
/// 5. Mark restart as required
@Observable
@MainActor
final class EnvironmentSwitchCoordinator {

    // MARK: - State

    /// The current phase of the switch flow.
    enum Phase: Equatable {
        /// No switch in progress.
        case idle
        /// Waiting for running sync to complete.
        case waitingForSync
        /// Attempting final sync push.
        case syncing
        /// Showing warning about unsynced data.
        case pendingConfirmation(outboxCount: Int)
        /// Switch completed, restart required.
        case restartRequired
    }

    /// The current phase of the environment switch.
    private(set) var phase: Phase = .idle

    /// Whether a switch is currently in progress.
    var isInProgress: Bool {
        phase != .idle && phase != .restartRequired
    }

    // MARK: - Dependencies

    private let authManager: AuthManager
    private let syncEngine: SyncEngine?
    private let storeWiper: StoreWiper

    // MARK: - Initialization

    init(
        authManager: AuthManager,
        syncEngine: SyncEngine?,
        storeWiper: StoreWiper
    ) {
        self.authManager = authManager
        self.syncEngine = syncEngine
        self.storeWiper = storeWiper
    }

    // MARK: - Switch Flow

    /// Initiates the environment switch flow.
    ///
    /// - Parameter targetEnvironment: The environment to switch to.
    func beginSwitch(to targetEnvironment: DataEnvironment) async {
        guard phase == .idle else { return }

        guard let syncEngine else {
            await completeSwitch(to: targetEnvironment)
            return
        }

        if syncEngine.status == .localOnly {
            syncEngine.refreshOutboxCount()
            let outboxCount = syncEngine.outboxCount
            if outboxCount > 0 {
                phase = .pendingConfirmation(outboxCount: outboxCount)
                return
            }

            await completeSwitch(to: targetEnvironment)
            return
        }

        // Wait for running sync
        if syncEngine.status == .syncing {
            phase = .waitingForSync
            await waitForSyncCompletion(syncEngine)
        }

        // Attempt final sync
        phase = .syncing
        await syncEngine.syncNow()
        syncEngine.refreshOutboxCount()

        // Check if there's unsynced data
        let outboxCount = syncEngine.outboxCount
        if outboxCount > 0 {
            // Sync failed or blocked with pending data - warn user
            phase = .pendingConfirmation(outboxCount: outboxCount)
            return
        }

        // No sync concerns or sync succeeded - proceed with switch
        await completeSwitch(to: targetEnvironment)
    }

    /// Confirms the switch despite unsynced data.
    ///
    /// Called when user acknowledges the warning about pending outbox data.
    func confirmSwitchDespiteUnsyncedData(to targetEnvironment: DataEnvironment) async {
        guard case .pendingConfirmation = phase else { return }
        phase = .syncing
        await syncEngine?.syncNow()
        await completeSwitch(to: targetEnvironment)
    }

    /// Cancels the pending switch.
    func cancelSwitch() {
        guard case .pendingConfirmation = phase else { return }
        phase = .idle
    }

    /// Resets the coordinator after app restart.
    func reset() {
        phase = .idle
    }

    // MARK: - Private

    private func waitForSyncCompletion(_ syncEngine: SyncEngine) async {
        // Poll until sync completes (with timeout)
        let timeout: TimeInterval = 30
        let start = Date()

        while syncEngine.status == .syncing {
            if Date().timeIntervalSince(start) > timeout {
                break
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func completeSwitch(to targetEnvironment: DataEnvironment) async {
        // Sign out if signed in
        if authManager.state.isSignedIn {
            try? await authManager.signOut()
        }

        // Wipe local store
        do {
            try await storeWiper.wipeAll()
        } catch {
            // Log but continue - best effort wipe
        }

        // Reset sync state if available
        syncEngine?.resetSyncState()

        // Persist the new environment selection
        DataEnvironment.persistSelection(targetEnvironment)

        // Mark restart required
        phase = .restartRequired
    }
}
