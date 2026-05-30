import Testing
@testable import Spread

/// `EntryRowView.Configuration` is now a type-level template with closures.
/// The action-availability and styling logic previously tested here has moved into the
/// configuration closures built at call sites (DaySpreadContentView, etc.).
///
/// This file is intentionally minimal — the old per-row struct tests no longer apply.
struct EntryRowConfigurationTests {

    /// Conditions: Default-initialized configuration.
    /// Expected: All optional closures are nil.
    @Test func testDefaultConfigurationHasNilClosures() {
        let config = EntryRowView.Configuration()

        #expect(config.isGreyedOut == nil)
        #expect(config.hasStrikethrough == nil)
        #expect(config.onStatusIconTap == nil)
        #expect(config.onEdit == nil)
        #expect(config.onDelete == nil)
        #expect(config.onTitleCommit == nil)
    }

    /// Conditions: Configuration with isGreyedOut closure that returns true.
    /// Expected: Closure returns true when called with any entry.
    @Test func testIsGreyedOutClosureIsCallable() {
        let task = DataModel.Task(title: "Test", status: .complete)
        let config = EntryRowView.Configuration(isGreyedOut: { _ in true })

        #expect(config.isGreyedOut?(task) == true)
    }
}
