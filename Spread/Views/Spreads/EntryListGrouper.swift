import class Foundation.DateFormatter
import struct Foundation.Calendar
import struct Foundation.Date

/// A section of grouped entries for display in an entry list.
///
/// Contains a title, date, and the entries belonging to this section.
/// Used by `EntryListView` to render grouped entries.
struct EntryListSection: Identifiable, Sendable {
    /// Unique identifier for the section.
    let id: Date

    /// The display title for the section header.
    ///
    /// For year spreads: "January 2026"
    /// For month spreads: "January 5"
    /// For day spreads: Empty string (no header shown)
    /// For multiday spreads: "January 5"
    let title: String

    /// The date this section represents.
    ///
    /// For year spreads: First day of the month
    /// For month/multiday spreads: The specific day
    /// For day spreads: The spread date
    let date: Date

    /// The entries in this section.
    let entries: [any Entry]
}

/// Groups entries based on spread period for display in entry lists.
///
/// Provides period-specific grouping logic:
/// - Year: Groups entries by month
/// - Month: Groups entries by day
/// - Day: Flat list (no grouping)
/// - Multiday: Groups entries by day within the range
struct EntryListGrouper: Sendable {

    // MARK: - Properties

    /// The spread period determining grouping strategy.
    let period: Period

    /// The spread's normalized date.
    let spreadDate: Date

    /// The calendar for date calculations.
    let calendar: Calendar

    // MARK: - Initialization

    /// Creates an entry list grouper.
    ///
    /// - Parameters:
    ///   - period: The spread period for grouping strategy.
    ///   - spreadDate: The spread's normalized date.
    ///   - calendar: The calendar for date calculations.
    init(period: Period, spreadDate: Date, calendar: Calendar) {
        self.period = period
        self.spreadDate = spreadDate
        self.calendar = calendar
    }

    // MARK: - Grouping

    /// Groups entries into sections based on the spread period.
    ///
    /// - Parameter entries: The entries to group.
    /// - Returns: An array of sections with grouped entries.
    func group(_ entries: [any Entry]) -> [EntryListSection] {
        guard !entries.isEmpty else { return [] }

        switch period {
        case .year:
            return groupByMonth(entries)
        case .month:
            return groupByDay(entries)
        case .day:
            return flatSection(entries)
        case .multiday:
            return groupByDay(entries)
        }
    }

    // MARK: - Grouping Strategies

    /// Groups entries by month for year spreads.
    private func groupByMonth(_ entries: [any Entry]) -> [EntryListSection] {
        var monthGroups: [Date: [any Entry]] = [:]

        for entry in entries {
            let entryDate = entryGroupingDate(for: entry)
            let monthStart = entryDate.firstDayOfMonth(calendar: calendar) ?? entryDate
            monthGroups[monthStart, default: []].append(entry)
        }

        return monthGroups.keys.sorted().map { monthDate in
            let sortedEntries = sortEntriesChronologically(monthGroups[monthDate] ?? [])
            return EntryListSection(
                id: monthDate,
                title: formatMonthTitle(monthDate),
                date: monthDate,
                entries: sortedEntries
            )
        }
    }

    /// Groups entries by day for month and multiday spreads.
    private func groupByDay(_ entries: [any Entry]) -> [EntryListSection] {
        var dayGroups: [Date: [any Entry]] = [:]

        for entry in entries {
            let entryDate = entryGroupingDate(for: entry)
            let dayStart = entryDate.startOfDay(calendar: calendar)
            dayGroups[dayStart, default: []].append(entry)
        }

        return dayGroups.keys.sorted().map { dayDate in
            let sortedEntries = sortEntriesChronologically(dayGroups[dayDate] ?? [])
            return EntryListSection(
                id: dayDate,
                title: formatDayTitle(dayDate),
                date: dayDate,
                entries: sortedEntries
            )
        }
    }

    /// Creates a single flat section for day spreads.
    private func flatSection(_ entries: [any Entry]) -> [EntryListSection] {
        let sortedEntries = sortEntriesChronologically(entries)
        return [
            EntryListSection(
                id: spreadDate,
                title: "",
                date: spreadDate,
                entries: sortedEntries
            )
        ]
    }

    // MARK: - Helper Methods

    /// Returns the date used for grouping an entry.
    ///
    /// For tasks and notes, uses the preferred date.
    /// For events, uses the start date.
    private func entryGroupingDate(for entry: any Entry) -> Date {
        switch entry.entryType {
        case .task:
            return (entry as? DataModel.Task)?.date ?? .now
        case .event:
            return (entry as? DataModel.Event)?.startDate ?? .now
        case .note:
            return (entry as? DataModel.Note)?.date ?? .now
        }
    }

    /// Sorts entries chronologically by their grouping date.
    private func sortEntriesChronologically(_ entries: [any Entry]) -> [any Entry] {
        entries.sorted { entryGroupingDate(for: $0) < entryGroupingDate(for: $1) }
    }

    /// Formats a month title like "January 2026".
    private func formatMonthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    /// Formats a day title like "January 5".
    private func formatDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }
}
