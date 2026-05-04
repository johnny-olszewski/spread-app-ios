import Foundation

struct SpreadPickerSelection: Equatable, Sendable {
    let period: Period
    let date: Date
    let spreadID: UUID?
}

struct SpreadPickerOption: Identifiable, Equatable, Sendable {
    enum Availability: Equatable, Sendable {
        case existing
        case uncreated
    }

    let id: String
    let title: String
    let subtitle: String
    let selection: SpreadPickerSelection
    let period: Period
    let availability: Availability
}

/// Configuration and logic for the spread picker in task creation.
///
/// Provides:
/// - Chronological spread ordering matching the spread tab bar
/// - Explicit or implicit year/month/day destination options
/// - Existing direct multiday destination options
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
    /// - Parameter periods: The set of periods to include. Empty means no filtering.
    /// - Returns: Filtered and sorted spreads.
    func filteredSpreads(periods: Set<Period>) -> [DataModel.Spread] {
        let periodsToInclude = periods.isEmpty ? Set(Period.allCases) : periods

        return spreads
            .filter { periodsToInclude.contains($0.period) }
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

    // MARK: - Destination Options

    func directDestinationOptions(for date: Date) -> [SpreadPickerOption] {
        [Period.year, .month, .day].map { period in
            let normalizedDate = period.normalizeDate(date, calendar: calendar)
            let existingSpread = spreads.first { spread in
                spread.period == period &&
                period.normalizeDate(spread.date, calendar: calendar) == normalizedDate
            }

            let title = existingSpread.map(displayLabel(for:)) ?? displayLabel(for: period, date: normalizedDate)
            let subtitle = subtitle(for: period, availability: existingSpread == nil ? .uncreated : .existing)

            return SpreadPickerOption(
                id: "\(period.rawValue)-\(normalizedDate.timeIntervalSinceReferenceDate)",
                title: title,
                subtitle: subtitle,
                selection: SpreadPickerSelection(
                    period: period,
                    date: normalizedDate,
                    spreadID: nil
                ),
                period: period,
                availability: existingSpread == nil ? .uncreated : .existing
            )
        }
    }

    func multidayOptions() -> [SpreadPickerOption] {
        filteredSpreads(periods: [.multiday]).map { spread in
            SpreadPickerOption(
                id: spread.id.uuidString,
                title: displayLabel(for: spread),
                subtitle: "Existing multiday spread",
                selection: SpreadPickerSelection(
                    period: .multiday,
                    date: spread.date,
                    spreadID: spread.id
                ),
                period: .multiday,
                availability: .existing
            )
        }
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

    func displayLabel(for period: Period, date: Date) -> String {
        let spread = DataModel.Spread(period: period, date: date, calendar: calendar)
        return displayLabel(for: spread)
    }

    func subtitle(for period: Period, availability: SpreadPickerOption.Availability) -> String {
        switch (period, availability) {
        case (.year, .existing):
            return "Existing year spread"
        case (.year, .uncreated):
            return "Uncreated year destination"
        case (.month, .existing):
            return "Existing month spread"
        case (.month, .uncreated):
            return "Uncreated month destination"
        case (.day, .existing):
            return "Existing day spread"
        case (.day, .uncreated):
            return "Uncreated day destination"
        case (.multiday, .existing):
            return "Existing multiday spread"
        case (.multiday, .uncreated):
            return "Uncreated multiday destination"
        }
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
