import Foundation

extension JournalManager {

    /// Returns existing spreads for all periods other than `currentPeriod` that contain **today**.
    ///
    /// These are the period-shortcut buttons shown on the leading edge of the spread header bar.
    /// They always point to today's spreads regardless of which spread's date is on screen.
    /// Results are sorted most-granular first (day → multiday → month → year).
    func todayContextSpreads(for currentPeriod: Period) -> [DataModel.Spread] {
        Period.allCases
            .filter { $0 != currentPeriod }
            .sorted { $0.granularityRank > $1.granularityRank }
            .compactMap { period in
                spreads.first { $0.period == period && $0.contains(date: today, calendar: calendar) }
            }
    }
}
