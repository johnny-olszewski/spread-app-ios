import Foundation
@testable import Spread

extension TestDataBuilders {

    /// A named set of hierarchical spreads for a given date.
    struct SpreadSet {
        /// Year spread containing `today`.
        let year: DataModel.Spread
        /// Month spread containing `today`.
        let month: DataModel.Spread
        /// Day spread for `today`.
        let day: DataModel.Spread
        /// Multiday spread spanning the week around `today` (Mon–Sun).
        let multiday: DataModel.Spread
        /// Previous month's spread (for cross-month boundary tests).
        let previousMonth: DataModel.Spread
        /// Next month's spread (for cross-month boundary tests).
        let nextMonth: DataModel.Spread
        /// A day spread for the last day of the current month.
        let monthEnd: DataModel.Spread

        /// All spreads in the set.
        var all: [DataModel.Spread] {
            [year, month, day, multiday, previousMonth, nextMonth, monthEnd]
        }
    }

    /// Creates a hierarchical set of spreads centered on `today`.
    ///
    /// Includes year, month, day, multiday, previous/next month, and
    /// month-end spreads for boundary coverage.
    static func spreads(
        calendar: Calendar = testCalendar,
        today: Date = testDate
    ) -> SpreadSet {
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: today)!
        let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: today)!

        // Last day of the current month
        let monthRange = calendar.range(of: .day, in: .month, for: today)!
        let monthEndDate = calendar.date(
            from: DateComponents(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: monthRange.upperBound - 1
            )
        )!

        // Multiday: 7-day window starting from the Monday of the week containing today
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7  // weekday 1=Sun, so Mon offset
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!

        return SpreadSet(
            year: DataModel.Spread(period: .year, date: today, calendar: calendar),
            month: DataModel.Spread(period: .month, date: today, calendar: calendar),
            day: DataModel.Spread(period: .day, date: today, calendar: calendar),
            multiday: DataModel.Spread(startDate: monday, endDate: sunday, calendar: calendar),
            previousMonth: DataModel.Spread(period: .month, date: previousMonthDate, calendar: calendar),
            nextMonth: DataModel.Spread(period: .month, date: nextMonthDate, calendar: calendar),
            monthEnd: DataModel.Spread(period: .day, date: monthEndDate, calendar: calendar)
        )
    }
}
