import Foundation
import Testing
@testable import Spread

struct SpreadMonthCalendarSupportTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// The month helper should enumerate every calendar day in the displayed month.
    /// Setup: February 2026 in a Gregorian UTC calendar.
    /// Expected: 28 dates spanning Feb 1 through Feb 28.
    @Test func testMonthDayDatesReturnsEveryDayInMonth() {
        let dates = SpreadMonthCalendarSupport.monthDayDates(
            monthDate: Self.makeDate(year: 2026, month: 2),
            calendar: Self.calendar
        )

        #expect(dates.count == 28)
        #expect(Self.calendar.component(.day, from: dates.first!) == 1)
        #expect(Self.calendar.component(.day, from: dates.last!) == 28)
    }

    /// Conventional month calendars should separate explicit day-spread existence from fallback month-hosted day content.
    /// Setup: Jan 12 has current day content on the month spread, while Jan 13 has an explicit empty day spread.
    /// Expected: Jan 12 is uncreated with content, and Jan 13 is created with no content.
    @Test func testConventionalDayStateSeparatesExplicitSpreadExistenceFromCurrentContent() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let fallbackDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let explicitEmptyDay = Self.makeDate(year: 2026, month: 1, day: 13)
        let explicitDaySpread = DataModel.Spread(period: .day, date: explicitEmptyDay, calendar: Self.calendar)

        var monthModel = SpreadDataModel(spread: monthSpread)
        monthModel.tasks = [DataModel.Task(title: "Fallback", date: fallbackDay, period: .day)]

        let states = SpreadMonthCalendarSupport.conventionalDayStateByDate(
            monthDate: monthDate,
            spreads: [explicitDaySpread],
            dataModel: [
                .day: [
                    Period.day.normalizeDate(explicitEmptyDay, calendar: Self.calendar): SpreadDataModel(
                        spread: explicitDaySpread
                    )
                ]
            ],
            monthSpreadDataModel: monthModel,
            calendar: Self.calendar
        )

        #expect(
            states[Period.day.normalizeDate(fallbackDay, calendar: Self.calendar)] ==
                SpreadMonthCalendarDayState(hasExplicitDaySpread: false, contentCount: 1)
        )
        #expect(
            states[Period.day.normalizeDate(explicitEmptyDay, calendar: Self.calendar)] ==
                SpreadMonthCalendarDayState(hasExplicitDaySpread: true, contentCount: 0)
        )
    }

    /// Conventional month calendars should also show content indicators for explicit day spreads when they hold current entries.
    /// Setup: Jan 12 has an explicit day spread whose own spread data model contains one task and one note.
    /// Expected: The day is created and reports two content items.
    @Test func testConventionalDayStateIncludesExplicitDaySpreadContent() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let explicitDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let explicitDaySpread = DataModel.Spread(period: .day, date: explicitDay, calendar: Self.calendar)

        var explicitDayModel = SpreadDataModel(spread: explicitDaySpread)
        explicitDayModel.tasks = [DataModel.Task(title: "Task", date: explicitDay, period: .day)]
        explicitDayModel.notes = [DataModel.Note(title: "Note", date: explicitDay, period: .day)]

        let states = SpreadMonthCalendarSupport.conventionalDayStateByDate(
            monthDate: monthDate,
            spreads: [explicitDaySpread],
            dataModel: [
                .day: [
                    Period.day.normalizeDate(explicitDay, calendar: Self.calendar): explicitDayModel
                ]
            ],
            monthSpreadDataModel: nil,
            calendar: Self.calendar
        )

        #expect(
            states[Period.day.normalizeDate(explicitDay, calendar: Self.calendar)] ==
                SpreadMonthCalendarDayState(hasExplicitDaySpread: true, contentCount: 2)
        )
    }

    /// Traditional month calendars should treat every day as navigable while still reporting current content counts.
    /// Setup: Jan 12 has two day tasks and one note in traditional mode.
    /// Expected: The day is created and reports three content items.
    @Test func testTraditionalDayStateUsesVirtualDayData() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)

        let states = SpreadMonthCalendarSupport.traditionalDayStateByDate(
            monthDate: monthDate,
            tasks: [
                DataModel.Task(title: "Task 1", date: dayDate, period: .day),
                DataModel.Task(title: "Task 2", date: dayDate, period: .day),
            ],
            notes: [
                DataModel.Note(title: "Note", date: dayDate, period: .day)
            ],
            events: [],
            calendar: Self.calendar
        )

        #expect(
            states[Period.day.normalizeDate(dayDate, calendar: Self.calendar)] ==
                SpreadMonthCalendarDayState(hasExplicitDaySpread: true, contentCount: 3)
        )
    }
}
