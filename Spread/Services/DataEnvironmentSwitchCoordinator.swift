import Foundation
import Observation

/// Coordinates the data environment switching flow.
///
/// Handles the process of switching data environments:
/// 1. Check outbox for unsynced data
/// 2. Warn if non-empty and require explicit confirmation
/// 3. Sign out, wipe local store, and mark restart required
///
/// Does not attempt sync — only checks outbox count. The user accepts
/// data loss when confirming a switch with pending outbox data.
@Observable
@MainActor
final class DataEnvironmentSwitchCoordinator {

    // MARK: - State

    /// The current phase of the switch flow.
    enum Phase: Equatable {
        /// No switch in progress.
        case idle
        /// Showing warning about unsynced data.
        case pendingConfirmation(outboxCount: Int)
        /// Switch completed, restart required.
        case restartRequired
    }

    /// The current phase of the environment switch.
    private(set) var phase: Phase = .idle

    /// Whether a switch is currently in progress.
    var isInProgress: Bool {
        if case .pendingConfirmation = phase { return true }
        return false
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
    /// Checks the outbox for unsynced data. If non-empty, transitions to
    /// `pendingConfirmation` so the user can confirm data loss. If empty
    /// (or no sync engine), proceeds directly to wipe and restart.
    ///
    /// - Parameter targetEnvironment: The environment to switch to.
    func beginSwitch(to targetEnvironment: DataEnvironment) async {
        guard phase == .idle else { return }

        if let syncEngine {
            syncEngine.refreshOutboxCount()
            let outboxCount = syncEngine.outboxCount
            if outboxCount > 0 {
                phase = .pendingConfirmation(outboxCount: outboxCount)
                return
            }
        }

        await completeSwitch(to: targetEnvironment)
    }

    /// Confirms the switch despite unsynced data.
    ///
    /// Called when user acknowledges the warning about pending outbox data.
    /// Proceeds directly to wipe without attempting sync.
    func confirmSwitchDespiteUnsyncedData(to targetEnvironment: DataEnvironment) async {
        guard case .pendingConfirmation = phase else { return }
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
