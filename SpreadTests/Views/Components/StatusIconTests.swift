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
}
