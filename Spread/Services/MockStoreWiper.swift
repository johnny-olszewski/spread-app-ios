/// Test double for `StoreWiper` that records calls.
///
/// Tracks whether `wipeAll()` was called and supports injecting errors.
@MainActor
final class MockStoreWiper: StoreWiper {

    /// The number of times `wipeAll()` has been called.
    private(set) var wipeAllCallCount = 0

    /// Optional error to throw from `wipeAll()`.
    var errorToThrow: (any Error)?

    func wipeAll() async throws {
        wipeAllCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
