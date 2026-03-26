import Foundation
import Testing
@testable import Spread

@Suite("Overdue Review Support Tests")
struct OverdueReviewSupportTests {

    /// Setup: overdue items from Inbox, a past year spread, and a current month spread.
    /// Expected: sections are grouped by source and ordered chronologically by spread date with Inbox first.
    @Test("overdue review groups tasks by source in stable chronological order")
    func overdueReviewGroupsTasksBySource() {
        let calendar = Calendar(identifier: .gregorian)
        let inboxTask = DataModel.Task(
            title: "Inbox",
            createdDate: calendar.date(from: DateComponents(year: 2025, month: 12, day: 20))!,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!,
            period: .month,
            status: .open
        )
        let yearTask = DataModel.Task(
            title: "Year",
            createdDate: calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            date: calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            period: .year,
            status: .open
        )
        let monthTask = DataModel.Task(
            title: "Month",
            createdDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            period: .month,
            status: .open
        )

        let sections = OverdueReviewGrouper(calendar: calendar).sections(for: [
            OverdueTaskItem(task: monthTask, sourceKey: TaskReviewSourceKey(kind: .spread(id: UUID(), period: .month, date: monthTask.date))),
            OverdueTaskItem(task: inboxTask, sourceKey: TaskReviewSourceKey(kind: .inbox)),
            OverdueTaskItem(task: yearTask, sourceKey: TaskReviewSourceKey(kind: .spread(id: UUID(), period: .year, date: yearTask.date))),
        ])

        #expect(sections.count == 3)
        #expect(sections[0].title == "From Inbox")
        #expect(sections[1].title == "From 2025")
        #expect(sections[2].title == "From January 2026")
    }
}
