import struct Foundation.Date
import Testing
@testable import Spread

struct SyncStatusTests {

    // MARK: - Display Text

    /// Conditions: Idle status.
    /// Expected: Display text should indicate no sync has occurred.
    @Test func testIdleDisplayText() {
        #expect(SyncStatus.idle.displayText == "Not synced")
    }

    /// Conditions: Syncing status.
    /// Expected: Display text should indicate sync is in progress.
    @Test func testSyncingDisplayText() {
        #expect(SyncStatus.syncing.displayText == "Syncing...")
    }

    /// Conditions: Offline status.
    /// Expected: Display text should indicate offline state.
    @Test func testOfflineDisplayText() {
        #expect(SyncStatus.offline.displayText == "Offline")
    }

    /// Conditions: Local only status.
    /// Expected: Display text should indicate local-only mode.
    @Test func testLocalOnlyDisplayText() {
        #expect(SyncStatus.localOnly.displayText == "Local only")
    }

    /// Conditions: Error status with message.
    /// Expected: Display text should be the error message.
    @Test func testErrorDisplayText() {
        let status = SyncStatus.error("Connection failed")
        #expect(status.displayText == "Connection failed")
    }

    // MARK: - System Image

    /// Conditions: Each status case.
    /// Expected: Each should return a non-empty SF Symbol name.
    @Test func testAllStatusesHaveSystemImage() {
        let statuses: [SyncStatus] = [
            .idle, .syncing, .synced(.now), .error("test"), .offline, .localOnly
        ]
        for status in statuses {
            #expect(!status.systemImage.isEmpty)
        }
    }

    // MARK: - isError

    /// Conditions: Error status.
    /// Expected: isError should be true.
    @Test func testIsErrorTrueForErrorStatus() {
        #expect(SyncStatus.error("fail").isError)
    }

    /// Conditions: Non-error statuses.
    /// Expected: isError should be false.
    @Test func testIsErrorFalseForNonErrorStatuses() {
        #expect(!SyncStatus.idle.isError)
        #expect(!SyncStatus.syncing.isError)
        #expect(!SyncStatus.synced(.now).isError)
        #expect(!SyncStatus.offline.isError)
        #expect(!SyncStatus.localOnly.isError)
    }

    // MARK: - Equatable

    /// Conditions: Two idle statuses.
    /// Expected: Should be equal.
    @Test func testEquatableIdle() {
        #expect(SyncStatus.idle == SyncStatus.idle)
    }

    /// Conditions: Two synced statuses with same date.
    /// Expected: Should be equal.
    @Test func testEquatableSynced() {
        let date = Date.now
        #expect(SyncStatus.synced(date) == SyncStatus.synced(date))
    }

    /// Conditions: Idle vs syncing.
    /// Expected: Should not be equal.
    @Test func testNotEqualDifferentCases() {
        #expect(SyncStatus.idle != SyncStatus.syncing)
    }
}
