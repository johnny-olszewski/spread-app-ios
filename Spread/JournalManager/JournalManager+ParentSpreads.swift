import Foundation

extension JournalManager {

    /// Returns existing spreads at less-granular periods containing **today**, scoped to
    /// periods broader than `currentPeriod`.
    ///
    /// These are the "This Month" / "This Year" context shortcuts shown on the leading edge
    /// of the spread header bar. They always point to today's broader-period spreads regardless
    /// of which spread's date is currently on screen.
    ///
    /// Results are sorted most-granular first (month before year):
    /// - **day** or **multiday**: today's month spread (if any), then today's year spread (if any).
    /// - **month**: today's year spread (if any).
    /// - **year**: always `[]`.
    func todayContextSpreads(for currentPeriod: Period) -> [DataModel.Spread] {
        switch currentPeriod {
        case .year:
            return []
        case .month:
            return spreads.filter { $0.period == .year && $0.contains(date: today, calendar: calendar) }
        case .day, .multiday:
            let month = spreads.first { $0.period == .month && $0.contains(date: today, calendar: calendar) }
            let year = spreads.first { $0.period == .year && $0.contains(date: today, calendar: calendar) }
            return [month, year].compactMap { $0 }
        }
    }
}
