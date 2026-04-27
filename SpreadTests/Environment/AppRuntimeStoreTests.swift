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
}

private enum TestError: Error, Equatable {
    case unexpectedPath
}
