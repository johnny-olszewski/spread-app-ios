import Foundation
import Testing
@testable import Spread

@Suite("Spread Auto Migration Feedback Support Tests")
struct SpreadAutoMigrationFeedbackSupportTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Creating a month from its parent year surface should reveal the destination locally on that year page.
    @Test func yearToMonthCreationUsesLocalMonthReveal() {
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let month = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar)
        let result = SpreadCreationOperationResult(
            spread: month,
            autoMigrationSummary: .init(taskCount: 1, noteCount: 1)
        )

        let behavior = SpreadAutoMigrationFeedbackSupport.revealBehavior(
            currentSelection: .conventional(year),
            creationResult: result,
            calendar: Self.calendar
        )

        #expect(
            behavior == .local(
                surfaceSpreadID: year.id,
                anchor: .yearMonth(Self.makeDate(year: 2026, month: 3))
            )
        )
    }

    /// Creating a day from its parent month surface should reveal the destination locally in that month list.
    @Test func monthToDayCreationUsesLocalDayReveal() {
        let month = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 14), calendar: Self.calendar)
        let result = SpreadCreationOperationResult(
            spread: day,
            autoMigrationSummary: .init(taskCount: 2, noteCount: 0)
        )

        let behavior = SpreadAutoMigrationFeedbackSupport.revealBehavior(
            currentSelection: .conventional(month),
            creationResult: result,
            calendar: Self.calendar
        )

        #expect(
            behavior == .local(
                surfaceSpreadID: month.id,
                anchor: .monthDay(Self.makeDate(year: 2026, month: 3, day: 14))
            )
        )
    }

    /// Creation from unrelated or non-parent surfaces should navigate to the new destination spread.
    @Test func unrelatedCreationNavigatesToDestinationHeader() {
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 10),
            endDate: Self.makeDate(year: 2026, month: 3, day: 16),
            calendar: Self.calendar
        )
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 14), calendar: Self.calendar)
        let result = SpreadCreationOperationResult(
            spread: day,
            autoMigrationSummary: .init(taskCount: 1, noteCount: 0)
        )

        let behavior = SpreadAutoMigrationFeedbackSupport.revealBehavior(
            currentSelection: .conventional(multiday),
            creationResult: result,
            calendar: Self.calendar
        )

        #expect(
            behavior == .navigate(
                surfaceSpreadID: day.id,
                anchor: .spreadHeader
            )
        )
    }

    /// Feedback should remain absent when no entries moved during explicit spread creation.
    @Test func feedbackIsNilWithoutAutoMigration() {
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 14), calendar: Self.calendar)
        let result = SpreadCreationOperationResult(spread: day, autoMigrationSummary: nil)

        let feedback = SpreadAutoMigrationFeedbackSupport.feedback(
            currentSelection: .conventional(day),
            creationResult: result,
            calendar: Self.calendar
        )

        #expect(feedback == nil)
    }
}
