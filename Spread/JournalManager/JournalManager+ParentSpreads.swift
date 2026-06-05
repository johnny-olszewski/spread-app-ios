import Foundation

extension JournalManager {

    /// Returns the ancestor spreads for `spread`, ordered broadest period → narrowest.
    ///
    /// Each entry carries the parent period and the matching spread if one exists in the
    /// journal, or `nil` when no spread has been created for that period yet.
    ///
    /// For `.day` spreads, a covering `.multiday` spread is included when one exists — it is
    /// omitted entirely when none exists (multiday is not a standard period, so no disabled
    /// placeholder is shown).
    ///
    /// Period rules:
    /// - `.year` → `[]` (no ancestors)
    /// - `.month` → `[(.year, spread?)]`
    /// - `.day` → `[(.year, spread?), (.month, spread?)]` + `(.multiday, spread)` if a
    ///   covering multiday spread exists
    /// - `.multiday` → `[(.year, spread?), (.month, spread?)]` using `startDate`
    func parentSpreads(for spread: DataModel.Spread) -> [(period: Period, spread: DataModel.Spread?)] {
        switch spread.period {
        case .year:
            return []
        case .month:
            return [(.year, matchingSpread(period: .year, referenceDate: spread.date))]
        case .day:
            var entries: [(period: Period, spread: DataModel.Spread?)] = [
                (.year, matchingSpread(period: .year, referenceDate: spread.date)),
                (.month, matchingSpread(period: .month, referenceDate: spread.date))
            ]
            if let multiday = coveringMultidaySpread(for: spread.date) {
                entries.append((.multiday, multiday))
            }
            return entries
        case .multiday:
            let ref = spread.startDate ?? spread.date
            return [
                (.year, matchingSpread(period: .year, referenceDate: ref)),
                (.month, matchingSpread(period: .month, referenceDate: ref))
            ]
        }
    }

    // MARK: - Private

    private func matchingSpread(period: Period, referenceDate: Date) -> DataModel.Spread? {
        let normalizedRef = period.normalizeDate(referenceDate, calendar: calendar)
        return spreads.first {
            $0.period == period &&
            period.normalizeDate($0.date, calendar: calendar) == normalizedRef
        }
    }

    /// Returns the first multiday spread whose date range covers `date`, or `nil` if none exists.
    private func coveringMultidaySpread(for date: Date) -> DataModel.Spread? {
        spreads.first { $0.period == .multiday && $0.contains(date: date, calendar: calendar) }
    }
}
