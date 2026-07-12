import Testing
@testable import Spread

@MainActor
struct AppRuntimeStoreTests {
    @Test("initializeIfNeeded creates runtime once")
    func initializeOnlyOnce() async throws {
        let dependencies = try AppDependencies.make()
        var invocationCount = 0

        let store = AppRuntimeStore(
            dependencies: dependencies,
            makeLiveRuntime: {
                Issue.record("Live runtime path should not be used in this test.")
                throw TestError.unexpectedPath
            },
            makeRuntime: { dependencies in
                invocationCount += 1
                return try await AppRuntimeBootstrapFactory.make(dependencies: dependencies)
            }
        )

        await store.initializeIfNeeded()
        await store.initializeIfNeeded()

        #expect(store.runtime != nil)
        #expect(store.initializationError == nil)
        #expect(invocationCount == 1)
    }

    @Test("initializeIfNeeded captures initialization errors")
    func initializeCapturesError() async {
        let store = AppRuntimeStore(
            makeLiveRuntime: {
                throw TestError.unexpectedPath
            }
        )

        await store.initializeIfNeeded()

        #expect(store.runtime == nil)
        #expect(store.initializationError as? TestError == .unexpectedPath)
    }

    /// Tests the in-place retry path behind the launch error screen (SPRD-303).
    ///
    /// Condition: The first initialization attempt throws; a second attempt succeeds.
    /// Expected: After the retry, the runtime exists and `initializationError` is
    /// cleared — the error → success transition the Try Again button relies on.
    @Test("Retry after a failed initialization succeeds and clears the error")
    func retryAfterFailureSucceeds() async throws {
        let dependencies = try AppDependencies.make()
        var attempt = 0

        let store = AppRuntimeStore(
            dependencies: dependencies,
            makeLiveRuntime: {
                Issue.record("Live runtime path should not be used in this test.")
                throw TestError.unexpectedPath
            },
            makeRuntime: { dependencies in
                attempt += 1
                if attempt == 1 { throw TestError.unexpectedPath }
                return try await AppRuntimeBootstrapFactory.make(dependencies: dependencies)
            }
        )

        await store.initializeIfNeeded()
        #expect(store.runtime == nil)
        #expect(store.initializationError as? TestError == .unexpectedPath)

        await store.initializeIfNeeded()
        #expect(store.runtime != nil)
        #expect(store.initializationError == nil)
        #expect(attempt == 2)
    }

    /// Tests that a persistent initialization failure stays in the error state.
    ///
    /// Condition: Every initialization attempt throws.
    /// Expected: After repeated retries the runtime remains nil and
    /// `initializationError` remains set — the error screen re-presents, no crash.
    @Test("Persistent initialization failure stays in the error state across retries")
    func persistentFailureStaysInErrorState() async {
        var attempt = 0
        let store = AppRuntimeStore(
            makeLiveRuntime: {
                attempt += 1
                throw TestError.unexpectedPath
            }
        )

        await store.initializeIfNeeded()
        await store.initializeIfNeeded()

        #expect(store.runtime == nil)
        #expect(store.initializationError as? TestError == .unexpectedPath)
        #expect(attempt == 2)
    }
}

private enum TestError: Error, Equatable {
    case unexpectedPath
}
