import Foundation

extension JournalManager {

    /// Returns existing spreads at less-granular periods that contain the given spread's dates.
    ///
    /// Results are sorted most-granular first (month before year):
    /// - **day**: containing month spread (if any), then containing year spread (if any).
    /// - **month**: containing year spread (if any).
    /// - **multiday**: all month spreads overlapping the range (if any), then all overlapping year spreads (if any).
    /// - **year**: always `[]`.
    func containingParentSpreads(for spread: DataModel.Spread) -> [DataModel.Spread] {
        switch spread.period {
        case .year:
            return []
        case .month:
            return spreads.filter { $0.period == .year && $0.contains(date: spread.date, calendar: calendar) }
        case .day:
            let months = spreads.filter { $0.period == .month && $0.contains(date: spread.date, calendar: calendar) }
            let years = spreads.filter { $0.period == .year && $0.contains(date: spread.date, calendar: calendar) }
            return months + years
        case .multiday:
            guard let start = spread.startDate, let end = spread.endDate else { return [] }
            let monthKeys = normalizedPeriodKeys(.month, from: start, to: end)
            let yearKeys = normalizedPeriodKeys(.year, from: start, to: end)
            let months = spreads.filter {
                $0.period == .month && monthKeys.contains(Period.month.normalizeDate($0.date, calendar: calendar))
            }
            let years = spreads.filter {
                $0.period == .year && yearKeys.contains(Period.year.normalizeDate($0.date, calendar: calendar))
            }
            return months + years
        }
    }

    /// Returns all unique normalized period-start dates covered by the inclusive date range.
    ///
    /// Iterates by period-sized steps (not day-by-day) so performance is bounded by the number
    /// of periods spanned, not the number of days.
    private func normalizedPeriodKeys(_ period: Period, from start: Date, to end: Date) -> Set<Date> {
        guard let component = period.calendarComponent else { return [] }
        var keys = Set<Date>()
        var current = period.normalizeDate(start, calendar: calendar)
        let normalizedEnd = period.normalizeDate(end, calendar: calendar)
        while current <= normalizedEnd {
            keys.insert(current)
            guard let next = calendar.date(byAdding: component, value: 1, to: current) else { break }
            current = next
        }
        return keys
    }
}
