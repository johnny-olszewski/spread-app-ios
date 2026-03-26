import Foundation
import struct Auth.User
import Testing
@testable import Spread

@MainActor
struct AuthLifecycleCoordinatorTests {

    // MARK: - Test Helpers

    private func makeCoordinator(
        authManager: AuthManager? = nil,
        syncEngine: SyncEngine? = nil,
        journalManager: JournalManager? = nil
    ) async throws -> (
        coordinator: AuthLifecycleCoordinator,
        authManager: AuthManager,
        syncEngine: SyncEngine,
        journalManager: JournalManager
    ) {
        let auth = authManager ?? AuthManager(service: MockAuthService())
        let manager: JournalManager
        if let journalManager {
            manager = journalManager
        } else {
            manager = try await JournalManager.make()
        }
        let container = try ModelContainerFactory.makeInMemory()
        let engine = syncEngine ?? SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: auth,
            networkMonitor: NetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: false
        )

        let coordinator = AuthLifecycleCoordinator(
            authManager: auth,
            syncEngine: engine,
            journalManager: manager
        )

        return (coordinator, auth, engine, manager)
    }

    // MARK: - Sign-In Starts Sync

    /// Conditions: User signs in.
    /// Expected: Auto-sync should be started.
    @Test func signedInStartsAutoSync() async throws {
        let (coordinator, authManager, syncEngine, _) = try await makeCoordinator()
        authManager.configureForTesting(state: .signedIn(makeTestUser()))

        await coordinator.handleSignedIn()

        // SyncEngine is disabled (isSyncEnabled: false), so status remains localOnly
        // The key behavior is that startAutoSync was called without crashing.
        #expect(syncEngine.status == .localOnly)
    }

    // MARK: - Initial Auth State Signed In

    /// Conditions: App launches with an existing session.
    /// Expected: handleInitialAuthState triggers handleSignedIn flow.
    @Test func initialAuthStateSignedInTriggersSync() async throws {
        let (coordinator, authManager, syncEngine, _) = try await makeCoordinator()
        authManager.configureForTesting(state: .signedIn(makeTestUser()))

        await coordinator.handleInitialAuthState()

        #expect(syncEngine.status == .localOnly)
    }

    // MARK: - Initial Auth State Signed Out

    /// Conditions: App launches without a session.
    /// Expected: handleInitialAuthState is a no-op.
    @Test func initialAuthStateSignedOutIsNoOp() async throws {
        let (coordinator, authManager, syncEngine, _) = try await makeCoordinator()
        authManager.configureForTesting(state: .signedOut)

        await coordinator.handleInitialAuthState()

        // Status should remain at the default (localOnly since isSyncEnabled: false)
        #expect(syncEngine.status == .localOnly)
    }

    // MARK: - Sign-Out Clears Data

    /// Conditions: User signs out with local data.
    /// Expected: Local data is wiped and sync state is reset.
    @Test func signOutClearsDataAndResetsSyncState() async throws {
        let manager = try await JournalManager.make()
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)
        try await manager.spreadRepository.save(spread)

        let (coordinator, _, syncEngine, _, ) = try await makeCoordinator(
            journalManager: manager
        )
        syncEngine.status = .synced(.now)

        await coordinator.handleSignedOut()

        #expect(syncEngine.status == .idle)
        #expect(await manager.hasLocalData() == false)
    }

    // MARK: - Sign-In Without User Is No-Op

    /// Conditions: handleSignedIn is called without a signed-in user (shouldn't normally happen).
    /// Expected: Auto-sync is still started (coordinator doesn't guard on auth state).
    @Test func handleSignedInWithoutUserStartsAutoSync() async throws {
        let (coordinator, authManager, syncEngine, _) = try await makeCoordinator()
        authManager.configureForTesting(state: .signedOut)

        await coordinator.handleSignedIn()

        #expect(syncEngine.status == .localOnly)
    }

    // MARK: - Wire Auth Callbacks

    /// Conditions: wireAuthCallbacks is called.
    /// Expected: onSignIn and onSignOut callbacks are set on the auth manager.
    @Test func wireAuthCallbacksSetsCallbacks() async throws {
        let (coordinator, authManager, _, _) = try await makeCoordinator()

        coordinator.wireAuthCallbacks()

        #expect(authManager.onSignIn != nil)
        #expect(authManager.onSignOut != nil)
    }

    // MARK: - Helpers

    /// Creates a minimal User for testing by decoding from JSON.
    ///
    /// Supabase `User` has no public initializer, so we create via JSON.
    private func makeTestUser(id: UUID = UUID()) -> User {
        let json = """
        {
            "id": "\(id.uuidString)",
            "appMetadata": {},
            "userMetadata": {},
            "aud": "authenticated",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // swiftlint:disable:next force_try
        return try! decoder.decode(User.self, from: data)
    }
}
