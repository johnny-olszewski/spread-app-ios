import Testing
@testable import Spread

/// Tests for `EntryStatusButtonRepresentable` conformances on all three entry status types.
///
/// Each conformance determines the icon shape, overlay, interactivity, and accessibility
/// label for that status — eliminating entry-type branching from rendering components.
@Suite("EntryStatusButtonRepresentable Conformance Tests")
struct EntryStatusButtonRepresentableTests {

    // MARK: - DataModel.Task.Status — base shape

    /// Conditions: Any task status.
    /// Expected: Base shape is .filledCircle for all task statuses.
    @Test("Task statuses all use filledCircle base shape")
    func testTaskStatusBaseShape() {
        for status in DataModel.Task.Status.allCases {
            #expect(status.iconBaseShape == .filledCircle)
        }
    }

    // MARK: - DataModel.Task.Status — overlays

    /// Conditions: Task status is .open.
    /// Expected: No overlay.
    @Test("Open task has no overlay")
    func testOpenTaskHasNoOverlay() {
        #expect(DataModel.Task.Status.open.iconOverlay == nil)
    }

    /// Conditions: Task status is .complete.
    /// Expected: xmark overlay.
    @Test("Complete task has xmark overlay")
    func testCompleteTaskHasXmarkOverlay() {
        #expect(DataModel.Task.Status.complete.iconOverlay == .xmark)
    }

    /// Conditions: Task status is .migrated.
    /// Expected: arrowRight overlay.
    @Test("Migrated task has arrowRight overlay")
    func testMigratedTaskHasArrowRightOverlay() {
        #expect(DataModel.Task.Status.migrated.iconOverlay == .arrowRight)
    }

    /// Conditions: Task status is .cancelled.
    /// Expected: slash overlay.
    @Test("Cancelled task has slash overlay")
    func testCancelledTaskHasSlashOverlay() {
        #expect(DataModel.Task.Status.cancelled.iconOverlay == .slash)
    }

    // MARK: - DataModel.Task.Status — interactivity

    /// Conditions: Task status is .open or .complete.
    /// Expected: Interactive (can toggle completion).
    @Test("Open and complete tasks are interactive")
    func testOpenAndCompleteAreInteractive() {
        #expect(DataModel.Task.Status.open.isInteractive == true)
        #expect(DataModel.Task.Status.complete.isInteractive == true)
    }

    /// Conditions: Task status is .migrated or .cancelled.
    /// Expected: Not interactive.
    @Test("Migrated and cancelled tasks are not interactive")
    func testMigratedAndCancelledAreNotInteractive() {
        #expect(DataModel.Task.Status.migrated.isInteractive == false)
        #expect(DataModel.Task.Status.cancelled.isInteractive == false)
    }

    // MARK: - DataModel.Note.Status — base shape

    /// Conditions: Any note status.
    /// Expected: Base shape is .dash for all note statuses.
    @Test("Note statuses all use dash base shape")
    func testNoteStatusBaseShape() {
        for status in DataModel.Note.Status.allCases {
            #expect(status.iconBaseShape == .dash)
        }
    }

    // MARK: - DataModel.Note.Status — overlays

    /// Conditions: Note status is .active.
    /// Expected: No overlay.
    @Test("Active note has no overlay")
    func testActiveNoteHasNoOverlay() {
        #expect(DataModel.Note.Status.active.iconOverlay == nil)
    }

    /// Conditions: Note status is .migrated.
    /// Expected: arrowRight overlay.
    @Test("Migrated note has arrowRight overlay")
    func testMigratedNoteHasArrowRightOverlay() {
        #expect(DataModel.Note.Status.migrated.iconOverlay == .arrowRight)
    }

    // MARK: - DataModel.Note.Status — interactivity

    /// Conditions: Any note status.
    /// Expected: Notes are never interactive.
    @Test("Notes are not interactive")
    func testNotesAreNotInteractive() {
        for status in DataModel.Note.Status.allCases {
            #expect(status.isInteractive == false)
        }
    }

    // MARK: - DataModel.Event.Status

    /// Conditions: Event status is .upcoming.
    /// Expected: Base shape is .emptyCircle.
    @Test("Upcoming event uses emptyCircle base shape")
    func testUpcomingEventBaseShape() {
        #expect(DataModel.Event.Status.upcoming.iconBaseShape == .emptyCircle)
    }

    /// Conditions: Event status is .upcoming.
    /// Expected: No overlay.
    @Test("Upcoming event has no overlay")
    func testUpcomingEventHasNoOverlay() {
        #expect(DataModel.Event.Status.upcoming.iconOverlay == nil)
    }

    /// Conditions: Event status is .upcoming.
    /// Expected: Not interactive.
    @Test("Events are not interactive")
    func testEventsAreNotInteractive() {
        #expect(DataModel.Event.Status.upcoming.isInteractive == false)
    }
}
