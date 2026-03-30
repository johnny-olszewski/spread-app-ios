import Foundation
import Testing
@testable import Spread

struct SpreadTitleNavigatorSupportTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func conventionalDaySelectionUsesChronologicalDayAndMultidayPeers() {
        let dayTen = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 10), calendar: Self.calendar)
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )
        let dayTwentyNine = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [dayTwentyNine, multiday, dayTen],
            tasks: [],
            notes: [],
            events: []
        )

        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: .conventional(dayTwentyNine))

        #expect(items.map(\.label) == ["10", "20-22", "29"])
        #expect(items.map(\.style) == [.day, .multiday, .day])
    }

    @Test func conventionalMonthSelectionUsesExplicitMonthsWithinYear() {
        let january = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let march = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar)
        let april = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 4), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [april, march, january],
            tasks: [],
            notes: [],
            events: []
        )

        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: .conventional(march))

        #expect(items.map(\.label) == ["Jan", "Mar", "Apr"])
        #expect(items.allSatisfy { $0.style == .month })
    }

    @Test func traditionalDaySelectionUsesAllDaysInMonth() {
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )

        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: .traditionalDay(Self.makeDate(year: 2026, month: 3, day: 29)))

        #expect(items.count == 31)
        #expect(items.first?.label == "1")
        #expect(items.last?.label == "31")
        #expect(items.allSatisfy { $0.style == .day })
    }

    @Test func metricsKeepCenteredSlotWithInvisibleInsets() {
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )
        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)

        let compact = stripModel.metrics(for: 320)
        let regular = stripModel.metrics(for: 900)

        #expect(compact.horizontalInset == (320 - compact.slotWidth) / 2)
        #expect(regular.horizontalInset == (900 - regular.slotWidth) / 2)
        #expect(compact.slotWidth < regular.slotWidth)
    }
}
