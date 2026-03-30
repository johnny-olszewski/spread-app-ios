import Foundation
import Testing
@testable import Spread

struct SpreadHeaderNavigatorSupportTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func conventionalMonthExpandsYearAndMonthOnOpen() {
        let march = Self.makeDate(year: 2026, month: 3)
        let currentSpread = DataModel.Spread(period: .month, date: march, calendar: Self.calendar)
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [currentSpread],
            tasks: [],
            notes: [],
            events: []
        )

        let expansion = model.initialExpansion(for: currentSpread)
        #expect(expansion.expandedYear == 2026)
        #expect(expansion.expandedMonth == march)
    }

    @Test func conventionalYearAndMonthRowsSupportDerivedNavigation() {
        let derivedMonthDay = Self.makeDate(year: 2026, month: 3, day: 10)
        let explicitDay = DataModel.Spread(period: .day, date: derivedMonthDay, calendar: Self.calendar)

        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [explicitDay],
            tasks: [],
            notes: [],
            events: []
        )

        let yearRows = model.rootYears()
        #expect(yearRows.count == 1)
        #expect(yearRows[0].year == 2026)
        #expect(yearRows[0].isDerived)
        #expect(!yearRows[0].canDirectSelect)

        let monthRows = model.months(in: 2026)
        #expect(monthRows.count == 1)
        #expect(Self.calendar.component(.month, from: monthRows[0].date) == 3)
        #expect(monthRows[0].isDerived)
        #expect(!monthRows[0].canDirectSelect)
    }

    @Test func conventionalMonthGridOrdersExplicitDaysAndMultidaysChronologically() {
        let daySpread = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 10), calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )
        let laterDaySpread = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)

        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [laterDaySpread, multidaySpread, daySpread],
            tasks: [],
            notes: [],
            events: []
        )

        let items = model.monthGridItems(year: 2026, month: 3)
        #expect(items.count == 3)
        #expect(items.map(\.label) == ["10", multidaySpread.displayLabel(calendar: Self.calendar), "29"])
        #expect(items[1].isMultiday)
    }

    @Test func traditionalYearRangeStartsAtEarliestNavigableDataAndExtendsTenYears() {
        let earliestTask = DataModel.Task(title: "Legacy", date: Self.makeDate(year: 2024, month: 5, day: 3), period: .day)
        let today = Self.makeDate(year: 2026, month: 3, day: 29)
        let model = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: today,
            spreads: [],
            tasks: [earliestTask],
            notes: [],
            events: []
        )

        let years = model.rootYears().map(\.year)
        #expect(years.first == 2036)
        #expect(years.last == 2024)
        #expect(years.contains(2026))
    }

    @Test func traditionalMonthGridShowsAllCalendarDaysAndNoMultidayTiles() {
        let explicitMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )

        let model = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [explicitMultiday],
            tasks: [],
            notes: [],
            events: []
        )

        let items = model.monthGridItems(year: 2026, month: 3)
        #expect(items.count == 31)
        #expect(items.allSatisfy {
            if case .day = $0.kind { return true }
            return false
        })
        #expect(items.first?.label == "1")
        #expect(items.last?.label == "31")
    }

    @Test func accordionExpansionClosesSiblingYearAndMonth() {
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )

        let march = Self.makeDate(year: 2026, month: 3)
        let april = Self.makeDate(year: 2026, month: 4)

        let afterYear = model.toggledYear(2026, from: .init(expandedYear: nil, expandedMonth: nil))
        #expect(afterYear.expandedYear == 2026)
        #expect(afterYear.expandedMonth == nil)

        let afterMarch = model.toggledMonth(march, in: 2026, from: afterYear)
        #expect(afterMarch.expandedYear == 2026)
        #expect(afterMarch.expandedMonth == march)

        let afterApril = model.toggledMonth(april, in: 2026, from: afterMarch)
        #expect(afterApril.expandedYear == 2026)
        #expect(afterApril.expandedMonth == april)

        let afterDifferentYear = model.toggledYear(2025, from: afterApril)
        #expect(afterDifferentYear.expandedYear == 2025)
        #expect(afterDifferentYear.expandedMonth == nil)
    }
}
