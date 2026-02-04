import Testing
@testable import Spread

@MainActor
struct SyncLogTests {

    // MARK: - Appending Entries

    /// Conditions: Append an info entry.
    /// Expected: Log should contain one entry with info level.
    @Test func testAppendInfoEntry() {
        let log = SyncLog()

        log.info("test message")

        #expect(log.entries.count == 1)
        #expect(log.entries[0].level == .info)
        #expect(log.entries[0].message == "test message")
    }

    /// Conditions: Append a warning entry.
    /// Expected: Log should contain one entry with warning level.
    @Test func testAppendWarningEntry() {
        let log = SyncLog()

        log.warning("warning message")

        #expect(log.entries.count == 1)
        #expect(log.entries[0].level == .warning)
    }

    /// Conditions: Append an error entry.
    /// Expected: Log should contain one entry with error level.
    @Test func testAppendErrorEntry() {
        let log = SyncLog()

        log.error("error message")

        #expect(log.entries.count == 1)
        #expect(log.entries[0].level == .error)
    }

    // MARK: - Cap Behavior

    /// Conditions: Append more entries than the max capacity.
    /// Expected: Log should only retain the most recent entries up to maxEntries.
    @Test func testCapRemovesOldestEntries() {
        let log = SyncLog(maxEntries: 3)

        log.info("one")
        log.info("two")
        log.info("three")
        log.info("four")

        #expect(log.entries.count == 3)
        #expect(log.entries[0].message == "two")
        #expect(log.entries[2].message == "four")
    }

    /// Conditions: Append exactly maxEntries.
    /// Expected: All entries should be retained.
    @Test func testExactCapRetainsAllEntries() {
        let log = SyncLog(maxEntries: 2)

        log.info("one")
        log.info("two")

        #expect(log.entries.count == 2)
    }

    // MARK: - Clear

    /// Conditions: Append entries then clear.
    /// Expected: Log should be empty after clear.
    @Test func testClearRemovesAllEntries() {
        let log = SyncLog()

        log.info("one")
        log.warning("two")
        log.error("three")
        log.clear()

        #expect(log.entries.isEmpty)
    }
}
