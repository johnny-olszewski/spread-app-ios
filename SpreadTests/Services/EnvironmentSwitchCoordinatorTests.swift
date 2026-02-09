import Foundation
import SwiftData
import Testing
@testable import Spread

@MainActor
struct EnvironmentSwitchCoordinatorTests {

    // MARK: - Test Helpers

    private func makeCoordinator(
        syncEngine: SyncEngine? = nil,
        storeWiper: MockStoreWiper? = nil
    ) -> (
        coordinator: EnvironmentSwitchCoordinator,
        authManager: AuthManager,
        storeWiper: MockStoreWiper
    ) {
        let authManager = AuthManager(service: MockAuthService())
        let wiper = storeWiper ?? MockStoreWiper()
        let coordinator = EnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )
        return (coordinator, authManager, wiper)
    }

    private func makeSyncEngine(
        authManager: AuthManager,
        isSyncEnabled: Bool = false
    ) throws -> SyncEngine {
        let container = try ModelContainerFactory.makeForTesting()
        return SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: MockNetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: isSyncEnabled
        )
    }

    // MARK: - No sync engine (localhost mode)

    /// Conditions: No sync engine provided (e.g., localhost mode).
    /// Expected: Transitions directly from idle to restartRequired.
    @Test func beginSwitchWithNoSyncEngineGoesToRestartRequired() async {
        let (coordinator, _, wiper) = makeCoordinator(syncEngine: nil)

        await coordinator.beginSwitch(to: .development)

        #expect(coordinator.phase == .restartRequired)
        #expect(wiper.wipeAllCallCount == 1)
    }

    // MARK: - Local-only sync engine with empty outbox

    /// Conditions: Sync engine exists in localOnly mode, outbox is empty.
    /// Expected: Skips to restartRequired without pendingConfirmation.
    @Test func beginSwitchLocalOnlyEmptyOutboxGoesToRestartRequired() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let syncEngine = try makeSyncEngine(authManager: authManager, isSyncEnabled: false)
        let wiper = MockStoreWiper()
        let coordinator = EnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )

        await coordinator.beginSwitch(to: .development)

        #expect(coordinator.phase == .restartRequired)
        #expect(wiper.wipeAllCallCount == 1)
    }

    // MARK: - Local-only sync engine with non-empty outbox

    /// Conditions: Sync engine in localOnly mode has pending outbox mutations.
    /// Expected: Transitions to pendingConfirmation with outbox count.
    @Test func beginSwitchLocalOnlyNonEmptyOutboxGoesToPendingConfirmation() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let container = try ModelContainerFactory.makeForTesting()
        let syncEngine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: MockNetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: false
        )

        // Insert a mutation into the outbox
        let mutation = DataModel.SyncMutation(
            entityType: "tasks",
            entityId: UUID(),
            operation: "create",
            recordData: Data()
        )
        container.mainContext.insert(mutation)
        try container.mainContext.save()

        let wiper = MockStoreWiper()
        let coordinator = EnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )

        await coordinator.beginSwitch(to: .development)

        #expect(coordinator.phase == .pendingConfirmation(outboxCount: 1))
        #expect(wiper.wipeAllCallCount == 0)
    }

    // MARK: - Confirm despite unsynced data

    /// Conditions: Coordinator is in pendingConfirmation, user confirms.
    /// Expected: Transitions to restartRequired after wipe.
    @Test func confirmSwitchDespiteUnsyncedDataCompletesSwitch() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let container = try ModelContainerFactory.makeForTesting()
        let syncEngine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: MockNetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: false
        )

        let mutation = DataModel.SyncMutation(
            entityType: "tasks",
            entityId: UUID(),
            operation: "create",
            recordData: Data()
        )
        container.mainContext.insert(mutation)
        try container.mainContext.save()

        let wiper = MockStoreWiper()
        let coordinator = EnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )

        await coordinator.beginSwitch(to: .development)
        #expect(coordinator.phase == .pendingConfirmation(outboxCount: 1))

        await coordinator.confirmSwitchDespiteUnsyncedData(to: .development)

        #expect(coordinator.phase == .restartRequired)
        #expect(wiper.wipeAllCallCount == 1)
    }

    // MARK: - Cancel switch

    /// Conditions: Coordinator is in pendingConfirmation, user cancels.
    /// Expected: Returns to idle without wiping.
    @Test func cancelSwitchReturnsToIdle() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let container = try ModelContainerFactory.makeForTesting()
        let syncEngine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: MockNetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: false
        )

        let mutation = DataModel.SyncMutation(
            entityType: "tasks",
            entityId: UUID(),
            operation: "create",
            recordData: Data()
        )
        container.mainContext.insert(mutation)
        try container.mainContext.save()

        let wiper = MockStoreWiper()
        let coordinator = EnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )

        await coordinator.beginSwitch(to: .development)
        #expect(coordinator.phase == .pendingConfirmation(outboxCount: 1))

        coordinator.cancelSwitch()

        #expect(coordinator.phase == .idle)
        #expect(wiper.wipeAllCallCount == 0)
    }

    // MARK: - Guard: non-idle beginSwitch

    /// Conditions: Coordinator already in restartRequired phase.
    /// Expected: beginSwitch is a no-op.
    @Test func beginSwitchIgnoredWhenNotIdle() async {
        let (coordinator, _, _) = makeCoordinator(syncEngine: nil)

        await coordinator.beginSwitch(to: .development)
        #expect(coordinator.phase == .restartRequired)

        await coordinator.beginSwitch(to: .localhost)

        #expect(coordinator.phase == .restartRequired)
    }

    // MARK: - isInProgress

    /// Conditions: Various phases.
    /// Expected: isInProgress is true during waitingForSync, syncing, and pendingConfirmation; false for idle and restartRequired.
    @Test func isInProgressCorrectForPhases() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let container = try ModelContainerFactory.makeForTesting()
        let syncEngine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: MockNetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: false
        )

        let mutation = DataModel.SyncMutation(
            entityType: "tasks",
            entityId: UUID(),
            operation: "create",
            recordData: Data()
        )
        container.mainContext.insert(mutation)
        try container.mainContext.save()

        let wiper = MockStoreWiper()
        let coordinator = EnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )

        // idle
        #expect(!coordinator.isInProgress)

        // pendingConfirmation
        await coordinator.beginSwitch(to: .development)
        #expect(coordinator.isInProgress)

        // restartRequired
        await coordinator.confirmSwitchDespiteUnsyncedData(to: .development)
        #expect(!coordinator.isInProgress)
    }

    // MARK: - Reset

    /// Conditions: Coordinator in restartRequired.
    /// Expected: reset() returns to idle.
    @Test func resetReturnsToIdle() async {
        let (coordinator, _, _) = makeCoordinator(syncEngine: nil)

        await coordinator.beginSwitch(to: .development)
        #expect(coordinator.phase == .restartRequired)

        coordinator.reset()

        #expect(coordinator.phase == .idle)
    }

    // MARK: - Wipe error resilience

    /// Conditions: StoreWiper throws during wipeAll().
    /// Expected: Switch still completes to restartRequired.
    @Test func completeSwitchContinuesDespiteWipeError() async {
        let wiper = MockStoreWiper()
        wiper.errorToThrow = NSError(domain: "test", code: 1)
        let (coordinator, _, _) = makeCoordinator(syncEngine: nil, storeWiper: wiper)

        await coordinator.beginSwitch(to: .development)

        #expect(coordinator.phase == .restartRequired)
        #expect(wiper.wipeAllCallCount == 1)
    }
}
