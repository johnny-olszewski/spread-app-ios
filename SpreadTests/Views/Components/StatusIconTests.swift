//import Testing
//@testable import Spread
//
///// Tests for `EntryStatus` icon presentation — base shapes, overlays, and accessibility labels.
//@Suite("EntryStatus Icon Presentation Tests")
//struct EntryStatusIconPresentationTests {
//
//    // MARK: - Base shapes
//
//    /// Conditions: Any task status.
//    /// Expected: Base shape is .filledCircle for all task statuses.
//    @Test("Task statuses all use filledCircle base shape")
//    func testTaskStatusBaseShape() {
//        for status in EntryStatus.allCases {
//            if case .filledCircle = status.iconBaseShape(for: .task) { } else {
//                Issue.record("Expected filledCircle for task status \(status)")
//            }
//        }
//    }
//
//    /// Conditions: Any note status.
//    /// Expected: Base shape is .dash for all note statuses.
//    @Test("Note statuses all use dash base shape")
//    func testNoteStatusBaseShape() {
//        for status in EntryStatus.allCases {
//            if case .dash = status.iconBaseShape(for: .note) { } else {
//                Issue.record("Expected dash for note status \(status)")
//            }
//        }
//    }
//
//    /// Conditions: Any event status.
//    /// Expected: Base shape is .emptyCircle for all event statuses.
//    @Test("Event statuses all use emptyCircle base shape")
//    func testEventStatusBaseShape() {
//        for status in EntryStatus.allCases {
//            if case .emptyCircle = status.iconBaseShape(for: .event) { } else {
//                Issue.record("Expected emptyCircle for event status \(status)")
//            }
//        }
//    }
//
//    // MARK: - Overlays
//
//    /// Conditions: Task status is .open, .active, or .upcoming.
//    /// Expected: No overlay.
//    @Test("Non-terminated statuses have no overlay")
//    func testNonTerminatedStatusesHaveNoOverlay() {
//        #expect(EntryStatus.open.iconOverlay == nil)
//        #expect(EntryStatus.active.iconOverlay == nil)
//        #expect(EntryStatus.upcoming.iconOverlay == nil)
//    }
//
//    /// Conditions: Task status is .complete.
//    /// Expected: xmark overlay.
//    @Test("Complete status has xmark overlay")
//    func testCompleteHasXmarkOverlay() {
//        if case .xmark = EntryStatus.complete.iconOverlay { } else {
//            Issue.record("Expected xmark overlay for complete")
//        }
//    }
//
//    /// Conditions: Status is .migrated.
//    /// Expected: arrowRight overlay.
//    @Test("Migrated status has arrowRight overlay")
//    func testMigratedHasArrowRightOverlay() {
//        if case .arrowRight = EntryStatus.migrated.iconOverlay { } else {
//            Issue.record("Expected arrowRight overlay for migrated")
//        }
//    }
//
//    /// Conditions: Task status is .cancelled.
//    /// Expected: slash overlay.
//    @Test("Cancelled status has slash overlay")
//    func testCancelledHasSlashOverlay() {
//        if case .slash = EntryStatus.cancelled.iconOverlay { } else {
//            Issue.record("Expected slash overlay for cancelled")
//        }
//    }
//
//    // MARK: - Accessibility labels
//
//    /// Conditions: Various entry type and status combinations.
//    /// Expected: Accessibility labels describe the status in context of the entry type.
//    @Test("Accessibility labels match entry type context")
//    func testAccessibilityLabels() {
//        #expect(EntryStatus.open.accessibilityLabel(for: .task) == "Open task")
//        #expect(EntryStatus.complete.accessibilityLabel(for: .task) == "Complete task")
//        #expect(EntryStatus.migrated.accessibilityLabel(for: .task) == "Migrated task")
//        #expect(EntryStatus.cancelled.accessibilityLabel(for: .task) == "Cancelled task")
//        #expect(EntryStatus.active.accessibilityLabel(for: .note) == "Active note")
//        #expect(EntryStatus.migrated.accessibilityLabel(for: .note) == "Migrated note")
//        #expect(EntryStatus.upcoming.accessibilityLabel(for: .event) == "Event")
//    }
//}
