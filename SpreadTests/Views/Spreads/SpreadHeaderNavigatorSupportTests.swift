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

    /// A conventional navigator should only show months that have an explicit month spread or a day/multiday sub-spread.
    @Test func conventionalYearPagesShowOnlyMonthsWithMonthOrSubspreads() throws {
        let januaryMonth = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let marchDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 10), calendar: Self.calendar)
        let aprilMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 2),
            endDate: Self.makeDate(year: 2026, month: 4, day: 5),
            calendar: Self.calendar
        )

        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [januaryMonth, marchDay, aprilMultiday],
            tasks: [],
            notes: [],
            events: []
        )

        let page = try #require(model.yearPages().first)
        #expect(page.year == 2026)
        #expect(page.months.map { Self.calendar.component(.month, from: $0.date) } == [1, 3, 4])
    }

    /// A conventional day cell should expose both the direct day target and any covering multiday targets, with the day target first.
    @Test func conventionalMonthRowsDeriveSingleAndMultiTargetDays() throws {
        let directDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 21), calendar: Self.calendar)
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )

        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [directDay, multiday],
            tasks: [],
            notes: [],
            events: []
        )

        let march = try #require(model.months(in: 2026).first)
        let multiTargets = march.targets(for: Self.makeDate(year: 2026, month: 3, day: 21), calendar: Self.calendar)
        let noTargets = march.targets(for: Self.makeDate(year: 2026, month: 3, day: 19), calendar: Self.calendar)

        #expect(multiTargets.count == 2)
        #expect(!multiTargets[0].isMultiday)
        #expect(multiTargets[1].isMultiday)
        #expect(noTargets.isEmpty)
    }

    /// A traditional navigator should always show all months for a year and every day in the month as selectable.
    @Test func traditionalYearPagesAlwaysShowAllMonthsAndDays() throws {
        let today = Self.makeDate(year: 2026, month: 3, day: 29)
        let model = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: today,
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )

        let page = try #require(model.yearPages().first(where: { $0.year == 2026 }))
        let march = try #require(page.months.first(where: { Self.calendar.component(.month, from: $0.date) == 3 }))

        #expect(page.months.count == 12)
        #expect(march.targets(for: Self.makeDate(year: 2026, month: 3, day: 1), calendar: Self.calendar).count == 1)
        #expect(march.targets(for: Self.makeDate(year: 2026, month: 3, day: 31), calendar: Self.calendar).count == 1)
    }

    /// The navigator should open on the selected spread's year and expand its month when the current spread is month/day/multiday scoped.
    @Test func initialYearAndExpandedMonthReflectCurrentSpread() {
        let currentSpread = DataModel.Spread(period: .day, date: Self.makeDate(year: 2027, month: 5, day: 12), calendar: Self.calendar)
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [currentSpread],
            tasks: [],
            notes: [],
            events: []
        )

        #expect(model.initialYear(for: currentSpread) == 2027)
        #expect(model.initialExpandedMonth(for: currentSpread) == Self.makeDate(year: 2027, month: 5))
    }

    /// A selected multiday spread should highlight its swimlane, not every covered day cell.
    @Test func multidayCurrentSpreadDoesNotMarkCoveredDatesAsCurrentDaySelection() {
        let currentSpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 24),
            calendar: Self.calendar
        )
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [currentSpread],
            tasks: [],
            notes: [],
            events: []
        )

        #expect(!model.isCurrent(date: Self.makeDate(year: 2026, month: 3, day: 21), currentSpread: currentSpread))
    }
}
