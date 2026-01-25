import class Foundation.DateFormatter
import struct Foundation.Calendar
import struct Foundation.Date

/// Configuration and logic for the spread picker in task creation.
///
/// Provides:
/// - Chronological spread ordering matching the spread tab bar
/// - Period filter logic for multi-select toggles
/// - Multiday expansion to list contained dates
struct SpreadPickerConfiguration {

    // MARK: - Properties

    /// All spreads available for selection.
    let spreads: [DataModel.Spread]

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date (typically today).
    let today: Date

    // MARK: - Filtering

    /// Returns spreads filtered by the selected periods, ordered chronologically.
    ///
    /// Ordering follows the spread tab bar hierarchy:
    /// - Spreads sorted by date ascending
    /// - Within the same date range, ordered by period hierarchy (year → month → day → multiday)
    ///
    /// - Parameter periods: The set of periods to include.
    /// - Returns: Filtered and sorted spreads.
    func filteredSpreads(periods: Set<Period>) -> [DataModel.Spread] {
        spreads
            .filter { periods.contains($0.period) }
            .sorted { lhs, rhs in
                // Primary sort: by date (using start date for multiday)
                let lhsDate = lhs.period == .multiday ? (lhs.startDate ?? lhs.date) : lhs.date
                let rhsDate = rhs.period == .multiday ? (rhs.startDate ?? rhs.date) : rhs.date

                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }

                // Secondary sort: by period hierarchy (year < month < day < multiday)
                return lhs.period.sortOrder < rhs.period.sortOrder
            }
    }

    // MARK: - Multiday Expansion

    /// Returns all dates contained within a multiday spread.
    ///
    /// For non-multiday spreads, returns an empty array.
    ///
    /// - Parameter spread: The spread to expand.
    /// - Returns: Array of dates from startDate to endDate inclusive.
    func containedDates(for spread: DataModel.Spread) -> [Date] {
        guard spread.period == .multiday,
              let startDate = spread.startDate,
              let endDate = spread.endDate else {
            return []
        }

        var dates: [Date] = []
        var currentDate = startDate

        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return dates
    }

    // MARK: - Display Labels

    /// Returns a display label for the spread in the picker list.
    ///
    /// Format varies by period:
    /// - Year: "2026"
    /// - Month: "March 2026"
    /// - Day: "January 15, 2026"
    /// - Multiday: "Jan 13 - Jan 19, 2026"
    ///
    /// - Parameter spread: The spread to label.
    /// - Returns: Human-readable label for the spread.
    func displayLabel(for spread: DataModel.Spread) -> String {
        switch spread.period {
        case .year:
            return yearLabel(for: spread)
        case .month:
            return monthLabel(for: spread)
        case .day:
            return dayLabel(for: spread)
        case .multiday:
            return multidayLabel(for: spread)
        }
    }

    /// Returns a display label for a date within a multiday spread.
    ///
    /// - Parameter date: The date to label.
    /// - Returns: Label in format "January 15, 2026".
    func dateLabel(for date: Date) -> String {
        let formatter = dateFormatter
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    // MARK: - Private Helpers

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    private func yearLabel(for spread: DataModel.Spread) -> String {
        let year = calendar.component(.year, from: spread.date)
        return String(year)
    }

    private func monthLabel(for spread: DataModel.Spread) -> String {
        let formatter = dateFormatter
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: spread.date)
    }

    private func dayLabel(for spread: DataModel.Spread) -> String {
        let formatter = dateFormatter
        formatter.dateStyle = .long
        return formatter.string(from: spread.date)
    }

    private func multidayLabel(for spread: DataModel.Spread) -> String {
        guard let startDate = spread.startDate, let endDate = spread.endDate else {
            return ""
        }

        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        let startMonth = calendar.component(.month, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)

        let formatter = dateFormatter

        if startYear == endYear && startMonth == endMonth {
            // Same month: "Jan 13 - 19, 2026"
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: startDate)
            let endDay = calendar.component(.day, from: endDate)
            return "\(startStr) - \(endDay), \(startYear)"
        } else if startYear == endYear {
            // Same year, different months: "Jan 13 - Feb 2, 2026"
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: startDate)
            let endStr = formatter.string(from: endDate)
            return "\(startStr) - \(endStr), \(startYear)"
        } else {
            // Different years: "Dec 30, 2025 - Jan 2, 2026"
            formatter.dateFormat = "MMM d, yyyy"
            let startStr = formatter.string(from: startDate)
            let endStr = formatter.string(from: endDate)
            return "\(startStr) - \(endStr)"
        }
    }
}

// MARK: - Period Sort Order

private extension Period {
    /// Sort order for chronological display.
    var sortOrder: Int {
        switch self {
        case .year: return 0
        case .month: return 1
        case .day: return 2
        case .multiday: return 3
        }
    }
}
