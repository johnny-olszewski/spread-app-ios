import SwiftUI
import Testing
@testable import Spread

struct StatusIconTests {

    // MARK: - Entry Type Base Symbol Tests

    /// Conditions: Entry type is task.
    /// Expected: Base symbol is "circle.fill" (solid circle).
    @Test func testTaskEntryTypeHasSolidCircleSymbol() {
        let config = StatusIconConfiguration(entryType: .task)

        #expect(config.baseSymbol == "circle.fill")
    }

    /// Conditions: Entry type is event.
    /// Expected: Base symbol is "circle" (empty circle).
    @Test func testEventEntryTypeHasEmptyCircleSymbol() {
        let config = StatusIconConfiguration(entryType: .event)

        #expect(config.baseSymbol == "circle")
    }

    /// Conditions: Entry type is note.
    /// Expected: Base symbol is "minus" (dash).
    @Test func testNoteEntryTypeHasDashSymbol() {
        let config = StatusIconConfiguration(entryType: .note)

        #expect(config.baseSymbol == "minus")
    }

    // MARK: - Task Status Overlay Tests

    /// Conditions: Task status is open.
    /// Expected: No overlay symbol (nil).
    @Test func testOpenTaskStatusHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .task, taskStatus: .open)

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Task status is complete.
    /// Expected: Overlay symbol is "xmark".
    @Test func testCompleteTaskStatusHasXmarkOverlay() {
        let config = StatusIconConfiguration(entryType: .task, taskStatus: .complete)

        #expect(config.overlaySymbol == "xmark")
    }

    /// Conditions: Task status is migrated.
    /// Expected: Overlay symbol is "arrow.right".
    @Test func testMigratedTaskStatusHasArrowRightOverlay() {
        let config = StatusIconConfiguration(entryType: .task, taskStatus: .migrated)

        #expect(config.overlaySymbol == "arrow.right")
    }

    /// Conditions: Task status is cancelled.
    /// Expected: Overlay symbol is "line.diagonal".
    @Test func testCancelledTaskStatusHasSlashOverlay() {
        let config = StatusIconConfiguration(entryType: .task, taskStatus: .cancelled)

        #expect(config.overlaySymbol == "line.diagonal")
    }

    // MARK: - Non-Task Overlay Tests

    /// Conditions: Entry type is event (no task status).
    /// Expected: No overlay symbol.
    @Test func testEventHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .event)

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Entry type is note (no task status).
    /// Expected: No overlay symbol.
    @Test func testNoteHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .note)

        #expect(config.overlaySymbol == nil)
    }

    // MARK: - Default Configuration Tests

    /// Conditions: Configuration created with only entry type.
    /// Expected: Task status is nil by default.
    @Test func testDefaultTaskStatusIsNil() {
        let config = StatusIconConfiguration(entryType: .task)

        #expect(config.taskStatus == nil)
    }

    /// Conditions: Configuration created with entry type and no task status.
    /// Expected: No overlay is shown.
    @Test func testTaskWithNoStatusHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .task, taskStatus: nil)

        #expect(config.overlaySymbol == nil)
    }

    // MARK: - Size Configuration Tests

    /// Conditions: Configuration created with default size.
    /// Expected: Size is .body (default).
    @Test func testDefaultSizeIsBody() {
        let config = StatusIconConfiguration(entryType: .task)

        #expect(config.size == .body)
    }

    /// Conditions: Configuration created with custom size.
    /// Expected: Size matches the provided value.
    @Test func testCustomSizeIsRespected() {
        let config = StatusIconConfiguration(entryType: .task, size: .title)

        #expect(config.size == .title)
    }

    // MARK: - Overlay Scale Tests

    /// Conditions: Overlay symbol exists.
    /// Expected: Overlay scale is smaller than base (0.5).
    @Test func testOverlayScaleIsSmallerThanBase() {
        let config = StatusIconConfiguration(entryType: .task, taskStatus: .complete)

        #expect(config.overlayScale == 0.5)
    }

    /// Conditions: No overlay symbol.
    /// Expected: Overlay scale is still defined (for consistency).
    @Test func testOverlayScaleDefinedEvenWithoutOverlay() {
        let config = StatusIconConfiguration(entryType: .task)

        #expect(config.overlayScale == 0.5)
    }

    // MARK: - Note Status Overlay Tests

    /// Conditions: Note with active status.
    /// Expected: No overlay symbol (active notes show plain dash).
    @Test func testActiveNoteHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .note, noteStatus: .active)

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Note with migrated status.
    /// Expected: Overlay symbol is "arrow.right" (migrated notes show arrow on dash).
    @Test func testMigratedNoteHasArrowRightOverlay() {
        let config = StatusIconConfiguration(entryType: .note, noteStatus: .migrated)

        #expect(config.overlaySymbol == "arrow.right")
    }

    /// Conditions: Note with no status specified.
    /// Expected: No overlay symbol.
    @Test func testNoteWithNoStatusHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .note, noteStatus: nil)

        #expect(config.overlaySymbol == nil)
    }

    // MARK: - Past Event Overlay Tests

    /// Conditions: Event that is not past.
    /// Expected: No overlay symbol (current events show plain empty circle).
    @Test func testCurrentEventHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .event, isEventPast: false)

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Event that is past.
    /// Expected: Overlay symbol is "xmark" (past events show X on empty circle).
    @Test func testPastEventHasXmarkOverlay() {
        let config = StatusIconConfiguration(entryType: .event, isEventPast: true)

        #expect(config.overlaySymbol == "xmark")
    }

    /// Conditions: Event with no past status specified.
    /// Expected: No overlay symbol (defaults to current).
    @Test func testEventWithNoPastStatusHasNoOverlay() {
        let config = StatusIconConfiguration(entryType: .event)

        #expect(config.overlaySymbol == nil)
    }

    // MARK: - Mixed Parameter Tests

    /// Conditions: Task entry type with note status provided.
    /// Expected: Note status is ignored, only task status matters.
    @Test func testTaskIgnoresNoteStatus() {
        let config = StatusIconConfiguration(
            entryType: .task,
            taskStatus: .open,
            noteStatus: .migrated
        )

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Note entry type with task status provided.
    /// Expected: Task status is ignored, only note status matters.
    @Test func testNoteIgnoresTaskStatus() {
        let config = StatusIconConfiguration(
            entryType: .note,
            taskStatus: .complete,
            noteStatus: .active
        )

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Event entry type with isEventPast false but task status provided.
    /// Expected: Task status is ignored, event past status determines overlay.
    @Test func testEventIgnoresTaskStatus() {
        let config = StatusIconConfiguration(
            entryType: .event,
            taskStatus: .complete,
            isEventPast: false
        )

        #expect(config.overlaySymbol == nil)
    }

    /// Conditions: Task entry type with isEventPast true.
    /// Expected: Event past status is ignored for tasks.
    @Test func testTaskIgnoresEventPastStatus() {
        let config = StatusIconConfiguration(
            entryType: .task,
            taskStatus: .open,
            isEventPast: true
        )

        #expect(config.overlaySymbol == nil)
    }
}
