import Foundation

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

    /// Small contextual labels shown next to specific row titles in this section.
    let contextualLabels: [UUID: String]

    /// The period/date context used when creating a new task from this section.
    let creationPeriod: Period
    let creationDate: Date

    func contextualLabel(for entry: any Entry) -> String? {
        contextualLabels[entry.id]
    }
}

/// Groups entries based on spread period for display in entry lists.
///
/// Provides period-specific grouping logic:
/// - Year: Untitled current-year tasks, then month sections containing month/day tasks
/// - Month: Untitled current-month list containing month/day tasks
/// - Day: Flat list (no grouping)
/// - Multiday: Groups entries by day within the range
struct EntryListGrouper: Sendable {

    // MARK: - Properties

    /// The spread period determining grouping strategy.
    let period: Period

    /// The spread's normalized date.
    let spreadDate: Date

    /// The multiday spread start date, if applicable.
    let spreadStartDate: Date?

    /// The multiday spread end date, if applicable.
    let spreadEndDate: Date?

    /// The calendar for date calculations.
    let calendar: Calendar

    // MARK: - Initialization

    /// Creates an entry list grouper.
    ///
    /// - Parameters:
    ///   - period: The spread period for grouping strategy.
    ///   - spreadDate: The spread's normalized date.
    ///   - calendar: The calendar for date calculations.
    init(
        period: Period,
        spreadDate: Date,
        spreadStartDate: Date? = nil,
        spreadEndDate: Date? = nil,
        calendar: Calendar
    ) {
        self.period = period
        self.spreadDate = spreadDate
        self.spreadStartDate = spreadStartDate
        self.spreadEndDate = spreadEndDate
        self.calendar = calendar
    }

    // MARK: - Grouping

    /// Groups entries into sections based on the spread period.
    ///
    /// - Parameter entries: The entries to group.
    /// - Returns: An array of sections with grouped entries.
    func group(_ entries: [any Entry]) -> [EntryListSection] {
        switch period {
        case .year:
            guard !entries.isEmpty else { return [] }
            return groupByMonth(entries)
        case .month:
            guard !entries.isEmpty else { return [] }
            return groupByDay(entries)
        case .day:
            guard !entries.isEmpty else { return [] }
            return flatSection(entries)
        case .multiday:
            return groupByDayIncludingEmptyDates(entries)
        }
    }

    // MARK: - Grouping Strategies

    /// Groups entries by month for year spreads.
    private func groupByMonth(_ entries: [any Entry]) -> [EntryListSection] {
        var yearEntries: [any Entry] = []
        var monthGroups: [Date: [any Entry]] = [:]
        var contextualLabels: [Date: [UUID: String]] = [:]

        for entry in entries {
            let grouping = assignableGrouping(for: entry)

            switch grouping.period {
            case .year:
                yearEntries.append(entry)
            case .month:
                let monthStart = grouping.date.firstDayOfMonth(calendar: calendar) ?? grouping.date
                monthGroups[monthStart, default: []].append(entry)
            case .day:
                let monthStart = grouping.date.firstDayOfMonth(calendar: calendar) ?? grouping.date
                monthGroups[monthStart, default: []].append(entry)
                contextualLabels[monthStart, default: [:]][entry.id] = formatDayNumber(grouping.date)
            case .multiday:
                let monthStart = grouping.date.firstDayOfMonth(calendar: calendar) ?? grouping.date
                monthGroups[monthStart, default: []].append(entry)
            }
        }

        var sections: [EntryListSection] = []
        let sortedYearEntries = sortEntriesChronologically(yearEntries)
        if !sortedYearEntries.isEmpty {
            sections.append(
                EntryListSection(
                    id: spreadDate,
                    title: "",
                    date: spreadDate,
                    entries: sortedYearEntries,
                    contextualLabels: [:],
                    creationPeriod: .year,
                    creationDate: spreadDate
                )
            )
        }

        sections.append(
            contentsOf: monthGroups.keys.sorted().map { monthDate in
                let sortedEntries = sortEntriesChronologically(monthGroups[monthDate] ?? [])
                return EntryListSection(
                    id: monthDate,
                    title: formatMonthTitle(monthDate),
                    date: monthDate,
                    entries: sortedEntries,
                    contextualLabels: contextualLabels[monthDate] ?? [:],
                    creationPeriod: .month,
                    creationDate: monthDate
                )
            }
        )

        return sections
    }

    /// Groups entries by day for month and multiday spreads.
    private func groupByDay(_ entries: [any Entry]) -> [EntryListSection] {
        var contextualLabels: [UUID: String] = [:]

        for entry in entries {
            let grouping = assignableGrouping(for: entry)
            if grouping.period == .day {
                contextualLabels[entry.id] = formatDayNumber(grouping.date)
            }
        }

        return [
            EntryListSection(
                id: spreadDate,
                title: "",
                date: spreadDate,
                entries: sortEntriesChronologically(entries),
                contextualLabels: contextualLabels,
                creationPeriod: .month,
                creationDate: spreadDate
            )
        ]
    }

    /// Groups multiday entries by day while ensuring every covered day renders a section.
    private func groupByDayIncludingEmptyDates(_ entries: [any Entry]) -> [EntryListSection] {
        let startDate = (spreadStartDate ?? spreadDate).startOfDay(calendar: calendar)
        let endDate = (spreadEndDate ?? spreadDate).startOfDay(calendar: calendar)

        var dayGroups: [Date: [any Entry]] = [:]
        for entry in entries {
            let grouping = assignableGrouping(for: entry)
            guard grouping.period == .day else { continue }
            let entryDate = grouping.date.startOfDay(calendar: calendar)
            dayGroups[entryDate, default: []].append(entry)
        }

        var sections: [EntryListSection] = []
        var currentDate = startDate
        while currentDate <= endDate {
            let sortedEntries = sortEntriesChronologically(dayGroups[currentDate] ?? [])
            sections.append(
                EntryListSection(
                    id: currentDate,
                    title: "",
                    date: currentDate,
                    entries: sortedEntries,
                    contextualLabels: [:],
                    creationPeriod: .day,
                    creationDate: currentDate
                )
            )
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate.startOfDay(calendar: calendar)
        }

        return sections
    }

    /// Creates a single flat section for day spreads.
    private func flatSection(_ entries: [any Entry]) -> [EntryListSection] {
        let sortedEntries = sortEntriesChronologically(entries)
        return [
            EntryListSection(
                id: spreadDate,
                title: "",
                date: spreadDate,
                entries: sortedEntries,
                contextualLabels: [:],
                creationPeriod: .day,
                creationDate: spreadDate
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

    private func assignableGrouping(for entry: any Entry) -> (period: Period, date: Date) {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                return (task.period, task.date)
            }
        case .note:
            if let note = entry as? DataModel.Note {
                return (note.period, note.date)
            }
        case .event:
            break
        }

        return (.day, entryGroupingDate(for: entry))
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

    private func formatDayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
