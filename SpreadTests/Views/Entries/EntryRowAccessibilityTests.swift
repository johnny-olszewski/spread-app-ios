import Testing
@testable import Spread

struct EntryRowAccessibilityTests {

    // MARK: - accessibilityLabel Tests

    /// Conditions: Task row with open status.
    /// Expected: accessibilityLabel contains title, "Task", and "Open".
    @Test func taskRow_openStatus_accessibilityLabel_includesTitleTypeAndStatus() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .open, title: "Buy milk")

        let label = config.accessibilityLabel

        #expect(label.contains("Buy milk"))
        #expect(label.contains("Task"))
        #expect(label.contains("Open"))
    }

    /// Conditions: Task row with complete status.
    /// Expected: accessibilityLabel contains "Complete".
    @Test func taskRow_completeStatus_accessibilityLabel_includesCompleteStatus() {
        let config = EntryRowConfiguration(entryType: .task, taskStatus: .complete, title: "Buy milk")

        let label = config.accessibilityLabel

        #expect(label.contains("Complete"))
    }

    // MARK: - accessibilityValue Tests

    /// Conditions: Task row with high priority set.
    /// Expected: accessibilityValue contains "High priority".
    @Test func taskRow_highPriority_accessibilityValue_includesPriority() {
        let config = EntryRowConfiguration(
            entryType: .task,
            taskStatus: .open,
            title: "Buy milk",
            taskPriority: .high
        )

        let value = config.accessibilityValue

        #expect(value?.contains("High priority") == true)
    }

    /// Conditions: Task row with a due date label.
    /// Expected: accessibilityValue contains the due date label.
    @Test func taskRow_withDueDate_accessibilityValue_includesDueDate() {
        let config = EntryRowConfiguration(
            entryType: .task,
            taskStatus: .open,
            title: "Buy milk",
            taskDueDateLabel: "May 20"
        )

        let value = config.accessibilityValue

        #expect(value?.contains("Due May 20") == true)
    }
}
