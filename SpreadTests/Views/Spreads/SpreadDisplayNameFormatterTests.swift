import Foundation
import Testing
@testable import Spread

struct SpreadDisplayNameFormatterTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var formatter: SpreadDisplayNameFormatter {
        SpreadDisplayNameFormatter(
            calendar: calendar,
            today: date(2026, 4, 18),
            firstWeekday: .sunday
        )
    }

    @Test func customNameWinsOverDynamicNameAndIsTrimmed() {
        let spread = DataModel.Spread(
            period: .day,
            date: date(2026, 4, 18),
            calendar: calendar,
            customName: "  Launch Plan  ",
            usesDynamicName: true
        )

        let display = formatter.display(for: spread)

        #expect(display.primary == "Launch Plan")
        #expect(display.secondaryForHeader == "April 18, 2026")
        #expect(display.isPersonalized)
    }

    @Test func emptyCustomNameFallsBackToDynamicThenCanonical() {
        let dynamicSpread = DataModel.Spread(
            period: .day,
            date: date(2026, 4, 18),
            calendar: calendar,
            customName: "   ",
            usesDynamicName: true
        )
        let canonicalSpread = DataModel.Spread(
            period: .day,
            date: date(2026, 4, 18),
            calendar: calendar,
            customName: "   ",
            usesDynamicName: false
        )

        #expect(formatter.display(for: dynamicSpread).primary == "Today")
        #expect(formatter.display(for: canonicalSpread).primary == "April 18, 2026")
    }

    @Test func dayDynamicNamesCoverPreviousCurrentAndNextOnly() {
        let yesterday = DataModel.Spread(period: .day, date: date(2026, 4, 17), calendar: calendar)
        let today = DataModel.Spread(period: .day, date: date(2026, 4, 18), calendar: calendar)
        let tomorrow = DataModel.Spread(period: .day, date: date(2026, 4, 19), calendar: calendar)
        let later = DataModel.Spread(period: .day, date: date(2026, 4, 20), calendar: calendar)

        #expect(formatter.display(for: yesterday).primary == "Yesterday")
        #expect(formatter.display(for: today).primary == "Today")
        #expect(formatter.display(for: tomorrow).primary == "Tomorrow")
        #expect(formatter.display(for: later).primary == "April 20, 2026")
    }

    @Test func monthAndYearDynamicNamesCoverPreviousCurrentAndNextOnly() {
        let lastMonth = DataModel.Spread(period: .month, date: date(2026, 3, 1), calendar: calendar)
        let thisMonth = DataModel.Spread(period: .month, date: date(2026, 4, 1), calendar: calendar)
        let nextMonth = DataModel.Spread(period: .month, date: date(2026, 5, 1), calendar: calendar)
        let lastYear = DataModel.Spread(period: .year, date: date(2025, 1, 1), calendar: calendar)
        let thisYear = DataModel.Spread(period: .year, date: date(2026, 1, 1), calendar: calendar)
        let nextYear = DataModel.Spread(period: .year, date: date(2027, 1, 1), calendar: calendar)

        #expect(formatter.display(for: lastMonth).primary == "Last month")
        #expect(formatter.display(for: thisMonth).primary == "This month")
        #expect(formatter.display(for: nextMonth).primary == "Next month")
        #expect(formatter.display(for: lastYear).primary == "Last year")
        #expect(formatter.display(for: thisYear).primary == "This year")
        #expect(formatter.display(for: nextYear).primary == "Next year")
    }

    @Test func multidayDynamicNamesCoverWeekAndWeekendWindows() {
        let lastWeek = DataModel.Spread(
            startDate: date(2026, 4, 5),
            endDate: date(2026, 4, 11),
            calendar: calendar
        )
        let thisWeek = DataModel.Spread(
            startDate: date(2026, 4, 12),
            endDate: date(2026, 4, 18),
            calendar: calendar
        )
        let nextWeek = DataModel.Spread(
            startDate: date(2026, 4, 19),
            endDate: date(2026, 4, 25),
            calendar: calendar
        )
        let thisWeekend = DataModel.Spread(
            startDate: date(2026, 4, 18),
            endDate: date(2026, 4, 19),
            calendar: calendar
        )
        let arbitraryRange = DataModel.Spread(
            startDate: date(2026, 4, 16),
            endDate: date(2026, 4, 19),
            calendar: calendar
        )

        #expect(formatter.display(for: lastWeek).primary == "Last week")
        #expect(formatter.display(for: thisWeek).primary == "This week")
        #expect(formatter.display(for: nextWeek).primary == "Next week")
        #expect(formatter.display(for: thisWeekend).primary == "This weekend")
        #expect(formatter.display(for: arbitraryRange).primary == "16 Apr - 19 Apr")
    }

    @Test func duplicateCustomNamesAreAllowedByDisplayRules() {
        let first = DataModel.Spread(
            period: .month,
            date: date(2026, 4, 1),
            calendar: calendar,
            customName: "Travel",
            usesDynamicName: true
        )
        let second = DataModel.Spread(
            period: .day,
            date: date(2026, 4, 18),
            calendar: calendar,
            customName: "Travel",
            usesDynamicName: true
        )

        #expect(formatter.display(for: first).primary == "Travel")
        #expect(formatter.display(for: second).primary == "Travel")
    }
}
