import Foundation
import Testing
@testable import JohnnyOFoundationCore

struct MonthCalendarModelBuilderTests {
    private static var sundayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static var mondayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func testFebruary2026UsesMinimumFourWeeks() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 2, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true),
            today: Self.makeDate(year: 2026, month: 2, day: 1, calendar: Self.sundayFirstCalendar)
        )

        #expect(model.header.weekCount == 4)
        #expect(model.weeks.count == 4)
        #expect(model.weeks.allSatisfy { $0.slots.count == 7 })
    }

    @Test func testMondayFirstWeekdayOrdering() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 2, calendar: Self.mondayFirstCalendar),
            calendar: Self.mondayFirstCalendar
        )

        #expect(model.weekdays.first?.weekday == 2)
        #expect(model.weekdays.last?.weekday == 1)
    }

    @Test func testPeripheralDatesBecomeDaySlotsWhenEnabled() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )

        let firstWeek = model.weeks[0]
        let leadingPeripheralCount = firstWeek.slots.reduce(into: 0) { partialResult, slot in
            if case .day(let context) = slot, context.isPeripheral {
                partialResult += 1
            }
        }

        #expect(leadingPeripheralCount == 3)
    }

    @Test func testPeripheralDatesBecomePlaceholdersWhenDisabled() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: false)
        )

        let firstWeek = model.weeks[0]
        let leadingPlaceholderCount = firstWeek.slots.reduce(into: 0) { partialResult, slot in
            if case .placeholder(let context) = slot, context.isLeading {
                partialResult += 1
            }
        }

        #expect(leadingPlaceholderCount == 3)
    }

    @Test func testTodayFlagIsDerivedInDayContext() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15, calendar: Self.sundayFirstCalendar)
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            today: today
        )

        let matchingDay = model.weeks
            .flatMap(\.slots)
            .compactMap { slot -> MonthCalendarDayContext? in
                guard case .day(let context) = slot else { return nil }
                return Self.sundayFirstCalendar.isDate(context.date, inSameDayAs: today) ? context : nil
            }
            .first

        #expect(matchingDay?.isToday == true)
    }
}
