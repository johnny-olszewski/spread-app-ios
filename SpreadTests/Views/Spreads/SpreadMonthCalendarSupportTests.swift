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

    @Test func testMonthDayDatesReturnsEveryDayInMonth() {
        let dates = SpreadMonthCalendarSupport.monthDayDates(
            monthDate: Self.makeDate(year: 2026, month: 2),
            calendar: Self.calendar
        )

        #expect(dates.count == 28)
        #expect(Self.calendar.component(.day, from: dates.first!) == 1)
        #expect(Self.calendar.component(.day, from: dates.last!) == 28)
    }

    @Test func testConventionalEntryCountsOnlyIncludeExplicitDaySpreads() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let otherDay = Self.makeDate(year: 2026, month: 1, day: 13)
        let otherSpread = DataModel.Spread(period: .day, date: otherDay, calendar: Self.calendar)

        var january12Model = SpreadDataModel(spread: daySpread)
        january12Model.tasks = [DataModel.Task(title: "Task", date: dayDate, period: .day)]
        january12Model.notes = [DataModel.Note(title: "Note", date: dayDate, period: .day)]

        var january13Model = SpreadDataModel(spread: otherSpread)
        january13Model.tasks = [DataModel.Task(title: "Other", date: otherDay, period: .day)]

        let counts = SpreadMonthCalendarSupport.conventionalEntryCountsByDate(
            monthDate: monthDate,
            spreads: [daySpread, otherSpread],
            dataModel: [
                .day: [
                    Period.day.normalizeDate(dayDate, calendar: Self.calendar): january12Model,
                    Period.day.normalizeDate(otherDay, calendar: Self.calendar): january13Model,
                ]
            ],
            calendar: Self.calendar
        )

        #expect(counts[Period.day.normalizeDate(dayDate, calendar: Self.calendar)] == 2)
        #expect(counts[Period.day.normalizeDate(otherDay, calendar: Self.calendar)] == 1)
    }

    @Test func testTraditionalEntryCountsUseVirtualDayData() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)

        let counts = SpreadMonthCalendarSupport.traditionalEntryCountsByDate(
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

        #expect(counts[Period.day.normalizeDate(dayDate, calendar: Self.calendar)] == 3)
    }
}
