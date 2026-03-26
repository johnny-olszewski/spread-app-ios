import Foundation
import Testing
@testable import Spread

@Suite("Migration Review Support Tests")
struct MigrationReviewSupportTests {

    @Test("review grouper sections migration candidates by source and keeps destination explicit")
    func reviewGrouperSectionsCandidatesBySource() {
        // Setup: one inbox task and one year-spread task both eligible for the same month destination.
        let calendar = Calendar(identifier: .gregorian)
        let destinationDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let destination = DataModel.Spread(period: .month, date: destinationDate, calendar: calendar)

        let inboxTask = DataModel.Task(
            title: "Inbox task",
            createdDate: calendar.date(from: DateComponents(year: 2025, month: 12, day: 20))!,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!,
            period: .day,
            status: .open
        )
        let yearTask = DataModel.Task(
            title: "Year task",
            createdDate: calendar.date(from: DateComponents(year: 2025, month: 12, day: 21))!,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 8))!,
            period: .day,
            status: .open
        )

        let sourceSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let candidates = [
            MigrationCandidate(
                task: yearTask,
                sourceKey: TaskReviewSourceKey(kind: .spread(id: sourceSpread.id, period: .year, date: yearDate)),
                sourceSpread: sourceSpread,
                destination: destination
            ),
            MigrationCandidate(
                task: inboxTask,
                sourceKey: .init(kind: .inbox),
                sourceSpread: nil,
                destination: destination
            ),
        ]

        let sections = MigrationReviewGrouper(calendar: calendar).sections(
            for: candidates,
            destination: destination
        )

        #expect(sections.count == 2)
        #expect(sections[0].sourceTitle == "From Inbox")
        #expect(sections[0].sourceDisplayName == "Inbox")
        #expect(sections[0].destinationDisplayName == "January 2026")
        #expect(sections[1].sourceTitle == "From 2026")
        #expect(sections[1].destinationDisplayName == "January 2026")
    }

    @Test("revalidator keeps only latest matching candidates and reports skipped rows")
    func revalidatorSkipsStaleSelections() {
        // Setup: user selected two rows, but one changed source before submit.
        let calendar = Calendar(identifier: .gregorian)
        let destination = DataModel.Spread(
            period: .day,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!,
            calendar: calendar
        )
        let monthSource = DataModel.Spread(
            period: .month,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            calendar: calendar
        )
        let yearSource = DataModel.Spread(
            period: .year,
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            calendar: calendar
        )

        let stableTask = DataModel.Task(
            title: "Stable",
            createdDate: .now,
            date: destination.date,
            period: .day,
            status: .open
        )
        let staleTask = DataModel.Task(
            title: "Stale",
            createdDate: .now,
            date: destination.date,
            period: .day,
            status: .open
        )

        let selected = [
            MigrationCandidate(
                task: stableTask,
                sourceKey: TaskReviewSourceKey(kind: .spread(id: monthSource.id, period: .month, date: monthSource.date)),
                sourceSpread: monthSource,
                destination: destination
            ),
            MigrationCandidate(
                task: staleTask,
                sourceKey: TaskReviewSourceKey(kind: .spread(id: monthSource.id, period: .month, date: monthSource.date)),
                sourceSpread: monthSource,
                destination: destination
            ),
        ]
        let latest = [
            selected[0],
            MigrationCandidate(
                task: staleTask,
                sourceKey: TaskReviewSourceKey(kind: .spread(id: yearSource.id, period: .year, date: yearSource.date)),
                sourceSpread: yearSource,
                destination: destination
            ),
        ]

        let result = MigrationSelectionRevalidator().revalidate(selected: selected, against: latest)

        #expect(result.valid.count == 1)
        #expect(result.valid[0].task.id == stableTask.id)
        #expect(result.skippedCount == 1)
    }
}
