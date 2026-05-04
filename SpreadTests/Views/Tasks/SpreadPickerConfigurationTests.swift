import Foundation
import Testing
@testable import Spread

@Suite("SpreadPickerConfiguration Tests")
struct SpreadPickerConfigurationTests {
    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Spreads ordered chronologically")
    func spreadsOrderedChronologically() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2027, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 3, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 20, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar)
        ]

        let config = SpreadPickerConfiguration(spreads: spreads, calendar: calendar, today: today)
        let ordered = config.filteredSpreads(periods: Set(Period.allCases))

        #expect(ordered.map(\.period) == [.year, .month, .day, .day, .month, .year])
    }

    @Test("Direct destination options describe existing and uncreated surfaces")
    func directDestinationOptionsIncludeExistingAndUncreatedSurfaces() {
        let calendar = makeCalendar()
        let focusDate = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: focusDate, calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [monthSpread],
            calendar: calendar,
            today: focusDate
        )

        let options = config.directDestinationOptions(for: focusDate)

        #expect(options.map(\.period) == [.year, .month, .day])
        #expect(options[0].availability == .uncreated)
        #expect(options[1].availability == .existing)
        #expect(options[2].availability == .uncreated)
        #expect(options[1].selection.spreadID == nil)
    }

    @Test("Multiday options expose direct spread identity")
    func multidayOptionsExposeDirectSpreadIdentity() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let multiday = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 1, day: 13, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 19, calendar: calendar),
            calendar: calendar
        )

        let config = SpreadPickerConfiguration(spreads: [multiday], calendar: calendar, today: today)
        let options = config.multidayOptions()

        #expect(options.count == 1)
        #expect(options[0].selection.period == .multiday)
        #expect(options[0].selection.spreadID == multiday.id)
        #expect(options[0].availability == .existing)
    }

    @Test("Multiday display label shows compact same-month range")
    func multidayDisplayLabelShowsCompactSameMonthRange() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 1, day: 13, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 19, calendar: calendar),
            calendar: calendar
        )

        let config = SpreadPickerConfiguration(spreads: [spread], calendar: calendar, today: today)
        let label = config.displayLabel(for: spread)

        #expect(label == "Jan 13 - 19, 2026")
    }
}
