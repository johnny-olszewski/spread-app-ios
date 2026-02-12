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
        authManager: AuthManager? = nil,
        isSyncEnabled: Bool = false
    ) throws -> (SyncEngine, ModelContainer) {
        let auth = authManager ?? AuthManager(service: MockAuthService())
        let container = try ModelContainerFactory.makeInMemory()
        let engine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: auth,
            networkMonitor: MockNetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: isSyncEnabled
        )
        return (engine, container)
    }

    // MARK: - No sync engine

    /// Conditions: No sync engine provided (e.g., localhost mode).
    /// Expected: Transitions directly from idle to restartRequired.
    @Test func beginSwitchWithNoSyncEngineGoesToRestartRequired() async {
        let (coordinator, _, wiper) = makeCoordinator(syncEngine: nil)

        await coordinator.beginSwitch(to: .development)

        #expect(coordinator.phase == .restartRequired)
        #expect(wiper.wipeAllCallCount == 1)
    }

    // MARK: - Empty outbox

    /// Conditions: Sync engine exists with empty outbox.
    /// Expected: Skips to restartRequired without pendingConfirmation.
    @Test func beginSwitchEmptyOutboxGoesToRestartRequired() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let (syncEngine, _) = try makeSyncEngine(authManager: authManager)
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

    // MARK: - Non-empty outbox

    /// Conditions: Sync engine has pending outbox mutations.
    /// Expected: Transitions to pendingConfirmation with outbox count.
    @Test func beginSwitchNonEmptyOutboxGoesToPendingConfirmation() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let (syncEngine, container) = try makeSyncEngine(authManager: authManager)

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
    /// Expected: Transitions to restartRequired after wipe, no sync attempt.
    @Test func confirmSwitchDespiteUnsyncedDataCompletesSwitch() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let (syncEngine, container) = try makeSyncEngine(authManager: authManager)

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
        let (syncEngine, container) = try makeSyncEngine(authManager: authManager)

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
    /// Expected: isInProgress is true only during pendingConfirmation.
    @Test func isInProgressCorrectForPhases() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let (syncEngine, container) = try makeSyncEngine(authManager: authManager)

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

    // MARK: - Sync-enabled engine with empty outbox

    /// Conditions: Sync engine with sync enabled but empty outbox.
    /// Expected: Skips to restartRequired (no sync attempt).
    @Test func beginSwitchSyncEnabledEmptyOutboxGoesToRestartRequired() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let (syncEngine, _) = try makeSyncEngine(authManager: authManager, isSyncEnabled: true)
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

    // MARK: - Sync-enabled engine with non-empty outbox

    /// Conditions: Sync engine with sync enabled and pending outbox mutations.
    /// Expected: Transitions to pendingConfirmation (no sync attempt).
    @Test func beginSwitchSyncEnabledNonEmptyOutboxGoesToPendingConfirmation() async throws {
        let authManager = AuthManager(service: MockAuthService())
        let (syncEngine, container) = try makeSyncEngine(authManager: authManager, isSyncEnabled: true)

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
}
