import Testing
@testable import Spread

struct EntryRowConfigurationTests {

    // MARK: - Task Action Availability Tests

    /// Conditions: Task with open status.
    /// Expected: Complete action is available.
    @Test func testOpenTaskHasCompleteAction() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.canComplete == true)
    }

    /// Conditions: Task with open status.
    /// Expected: Migrate action is available.
    @Test func testOpenTaskHasMigrateAction() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.canMigrate == true)
    }

    /// Conditions: Task with complete status.
    /// Expected: Complete action is not available (already complete).
    @Test func testCompleteTaskCannotComplete() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .complete)

        #expect(config.canComplete == false)
    }

    /// Conditions: Task with complete status.
    /// Expected: Migrate action is not available.
    @Test func testCompleteTaskCannotMigrate() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .complete)

        #expect(config.canMigrate == false)
    }

    /// Conditions: Task with migrated status.
    /// Expected: Complete action is not available.
    @Test func testMigratedTaskCannotComplete() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .migrated)

        #expect(config.canComplete == false)
    }

    /// Conditions: Task with migrated status.
    /// Expected: Migrate action is not available (already migrated).
    @Test func testMigratedTaskCannotMigrate() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .migrated)

        #expect(config.canMigrate == false)
    }

    /// Conditions: Task with cancelled status.
    /// Expected: Complete action is not available.
    @Test func testCancelledTaskCannotComplete() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .cancelled)

        #expect(config.canComplete == false)
    }

    /// Conditions: Task with cancelled status.
    /// Expected: Migrate action is not available.
    @Test func testCancelledTaskCannotMigrate() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .cancelled)

        #expect(config.canMigrate == false)
    }

    // MARK: - Note Action Availability Tests

    /// Conditions: Note with active status.
    /// Expected: Complete action is not available (notes have no complete status).
    @Test func testActiveNoteCannotComplete() {
        let config = EntryRowConfiguration(entryType: .note, noteStatus: .active)

        #expect(config.canComplete == false)
    }

    /// Conditions: Note with active status.
    /// Expected: Migrate action is available (explicit-only).
    @Test func testActiveNoteHasMigrateAction() {
        let config = EntryRowConfiguration(entryType: .note, noteStatus: .active)

        #expect(config.canMigrate == true)
    }

    /// Conditions: Note with migrated status.
    /// Expected: Migrate action is not available.
    @Test func testMigratedNoteCannotMigrate() {
        let config = EntryRowConfiguration(entryType: .note, noteStatus: .migrated)

        #expect(config.canMigrate == false)
    }

    // MARK: - Event Action Availability Tests

    /// Conditions: Entry type is event.
    /// Expected: Complete action is not available (events have no status).
    @Test func testEventCannotComplete() {
        let config = EntryRowConfiguration(entryType: .event)

        #expect(config.canComplete == false)
    }

    /// Conditions: Entry type is event.
    /// Expected: Migrate action is not available (events don't migrate).
    @Test func testEventCannotMigrate() {
        let config = EntryRowConfiguration(entryType: .event)

        #expect(config.canMigrate == false)
    }

    /// Conditions: Entry type is event.
    /// Expected: Edit action is available.
    @Test func testEventHasEditAction() {
        let config = EntryRowConfiguration(entryType: .event)

        #expect(config.canEdit == true)
    }

    /// Conditions: Entry type is event.
    /// Expected: Delete action is available.
    @Test func testEventHasDeleteAction() {
        let config = EntryRowConfiguration(entryType: .event)

        #expect(config.canDelete == true)
    }

    // MARK: - Edit Action Availability Tests

    /// Conditions: Task with any status.
    /// Expected: Edit action is available.
    @Test func testTaskHasEditAction() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.canEdit == true)
    }

    /// Conditions: Note with any status.
    /// Expected: Edit action is available.
    @Test func testNoteHasEditAction() {
        let config = EntryRowConfiguration(entryType: .note, noteStatus: .active)

        #expect(config.canEdit == true)
    }

    // MARK: - Delete Action Availability Tests

    /// Conditions: Task with open status.
    /// Expected: Delete action is available.
    @Test func testTaskHasDeleteAction() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.canDelete == true)
    }

    /// Conditions: Note with active status.
    /// Expected: Delete action is available.
    @Test func testNoteHasDeleteAction() {
        let config = EntryRowConfiguration(entryType: .note, noteStatus: .active)

        #expect(config.canDelete == true)
    }

    // MARK: - Available Actions Collection Tests

    /// Conditions: Task with open status.
    /// Expected: Leading actions contain migrate, trailing contains complete.
    @Test func testOpenTaskLeadingAndTrailingActions() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.leadingActions.contains(.migrate))
        #expect(config.trailingActions.contains(.complete))
    }

    /// Conditions: Note with active status.
    /// Expected: Leading actions contain migrate, trailing does not contain complete.
    @Test func testActiveNoteLeadingActions() {
        let config = EntryRowConfiguration(entryType: .note, noteStatus: .active)

        #expect(config.leadingActions.contains(.migrate))
        #expect(config.trailingActions.contains(.complete) == false)
    }

    /// Conditions: Event entry.
    /// Expected: No migrate or complete in any actions.
    @Test func testEventHasNoMigrateOrCompleteActions() {
        let config = EntryRowConfiguration(entryType: .event)

        #expect(config.leadingActions.contains(.migrate) == false)
        #expect(config.trailingActions.contains(.migrate) == false)
        #expect(config.leadingActions.contains(.complete) == false)
        #expect(config.trailingActions.contains(.complete) == false)
    }

    // MARK: - Title and Migration Badge Tests

    /// Conditions: Configuration created with a title.
    /// Expected: Title is accessible.
    @Test func testTitleIsAccessible() {
        let config = EntryRowConfiguration(
            entryType: .task,
            taskStatus: .open,
            title: "Test Task"
        )

        #expect(config.title == "Test Task")
    }

    /// Conditions: Task with migrated status and destination info.
    /// Expected: Migration badge shows destination.
    @Test func testMigratedTaskShowsMigrationBadge() {
        let config = EntryRowConfiguration(
            entryType: .task,
            taskStatus: .migrated,
            migrationDestination: "January 2026"
        )

        #expect(config.showsMigrationBadge == true)
        #expect(config.migrationDestination == "January 2026")
    }

    /// Conditions: Task with open status.
    /// Expected: No migration badge shown.
    @Test func testOpenTaskHasNoMigrationBadge() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.showsMigrationBadge == false)
    }

    /// Conditions: Event entry.
    /// Expected: No migration badge shown.
    @Test func testEventHasNoMigrationBadge() {
        let config = EntryRowConfiguration(entryType: .event)

        #expect(config.showsMigrationBadge == false)
    }
}
