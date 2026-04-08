import Foundation
import Testing
@testable import Spread

struct EntryRowInlineEditSupportTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
    }

    /// Conditions: An open task row can inline edit its title.
    /// Expected: Tapping the row enters inline editing instead of opening the full sheet.
    @Test func testOpenTaskPrimaryInteractionUsesInlineEdit() {
        let interaction = EntryRowInlineEditSupport.primaryInteraction(
            entryType: .task,
            taskStatus: .open,
            canInlineEditTitle: true
        )

        #expect(interaction == .inlineEdit)
    }

    /// Conditions: A completed task row is tapped.
    /// Expected: The row opens the full edit sheet instead of inline editing.
    @Test func testCompletedTaskPrimaryInteractionUsesFullEditSheet() {
        let interaction = EntryRowInlineEditSupport.primaryInteraction(
            entryType: .task,
            taskStatus: .complete,
            canInlineEditTitle: true
        )

        #expect(interaction == .fullEditSheet)
    }

    /// Conditions: An open day task is already assigned to today.
    /// Expected: The inline migrate menu omits duplicate Today, but includes Tomorrow and both next-month options.
    @Test func testMigrationOptionsExcludeCurrentTodayAndProvideDescriptiveFutureLabels() {
        let task = DataModel.Task(
            title: "Reassign me",
            date: today,
            period: .day,
            status: .open
        )

        let options = EntryRowInlineEditSupport.migrationOptions(
            for: task,
            today: today,
            calendar: calendar
        )

        #expect(options.map(\.kind) == [.tomorrow, .nextMonth, .nextMonthSameDay])
        #expect(options.map(\.label) == ["Tomorrow", "February 2026", "February 12, 2026"])
    }

    /// Conditions: An inline draft title differs from the saved title and the user opens the sheet action.
    /// Expected: The draft title is committed before the edit action callback runs.
    @Test @MainActor func testPerformInlineActionCommitsDraftBeforeInvokingAction() async {
        var events: [String] = []

        await EntryRowInlineEditSupport.performInlineAction(
            draftTitle: "Updated Title",
            originalTitle: "Original Title",
            onCommit: { title in
                events.append("commit:\(title)")
            },
            action: {
                events.append("edit")
            }
        )

        #expect(events == ["commit:Updated Title", "edit"])
    }
}
