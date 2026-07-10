import Foundation
import Testing
@testable import Spread

struct SpreadsTabViewNavigatorDataTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A single `.day` spread in one year.
    /// Expected: it appears exactly once in `yearSpreads` for its year, and not in any other year.
    @Test func daySpreadAppearsOnceInItsYear() {
        let spread = DataModel.Spread(period: .day, date: date(2026, 3, 10), calendar: calendar)

        let result = SpreadsTabView.buildNavigatorCalendarData(spreads: [spread], calendar: calendar)

        #expect(result.yearSpreads[2026]?.map(\.id) == [spread.id])
        #expect(result.yearSpreads[2025] == nil)
    }

    /// A `.multiday` spread spanning many days within a single year.
    /// Expected: it appears exactly once in that year's `yearSpreads`, not once per day it spans
    /// (the bug this task fixes — the old per-render dedup walk was correct, but recomputed on
    /// every render; this proves the precomputed result is still deduped, not duplicated).
    @Test func multidaySpreadAppearsOnceDespiteSpanningManyDays() {
        let spread = DataModel.Spread(
            startDate: date(2026, 6, 1),
            endDate: date(2026, 6, 10),
            calendar: calendar
        )

        let result = SpreadsTabView.buildNavigatorCalendarData(spreads: [spread], calendar: calendar)

        #expect(result.yearSpreads[2026]?.map(\.id) == [spread.id])
        #expect(result.yearSpreads[2026]?.count == 1)
    }

    /// A `.multiday` spread that crosses a year boundary (Dec 28 -> Jan 3).
    /// Expected: it appears exactly once in *each* year it touches, since the navigator displays
    /// one year at a time and the spread is visible (and should render its overlay bar) in both.
    @Test func multidaySpreadCrossingYearBoundaryAppearsOnceInEachYear() {
        let spread = DataModel.Spread(
            startDate: date(2025, 12, 28),
            endDate: date(2026, 1, 3),
            calendar: calendar
        )

        let result = SpreadsTabView.buildNavigatorCalendarData(spreads: [spread], calendar: calendar)

        #expect(result.yearSpreads[2025]?.map(\.id) == [spread.id])
        #expect(result.yearSpreads[2026]?.map(\.id) == [spread.id])
    }

    /// `.year` and `.month` period spreads mixed in with `.day`/`.multiday` spreads.
    /// Expected: only `.day`/`.multiday` spreads appear in `yearSpreads`, matching the
    /// navigator's display semantics (year/month spreads are excluded from `calendarModels` too).
    @Test func yearAndMonthSpreadsAreExcluded() {
        let daySpread = DataModel.Spread(period: .day, date: date(2026, 5, 1), calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: date(2026, 1, 1), calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: date(2026, 5, 1), calendar: calendar)

        let result = SpreadsTabView.buildNavigatorCalendarData(
            spreads: [daySpread, yearSpread, monthSpread],
            calendar: calendar
        )

        #expect(result.yearSpreads[2026]?.map(\.id) == [daySpread.id])
    }

    /// Two distinct `.day` spreads in the same year.
    /// Expected: `selectedYearSpreads`-equivalent lookup returns both, in encounter order.
    @Test func multipleDaySpreadsInSameYearAllAppear() {
        let first = DataModel.Spread(period: .day, date: date(2026, 1, 5), calendar: calendar)
        let second = DataModel.Spread(period: .day, date: date(2026, 7, 20), calendar: calendar)

        let result = SpreadsTabView.buildNavigatorCalendarData(spreads: [first, second], calendar: calendar)

        #expect(result.yearSpreads[2026]?.map(\.id) == [first.id, second.id])
    }
}
