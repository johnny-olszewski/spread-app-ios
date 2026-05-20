import Foundation

/// Groups entries based on spread period for display in entry lists.
///
/// Provides period-specific grouping logic:
/// - Year: Untitled current-year tasks, then month sections containing month/day tasks
/// - Month: Untitled current-month list containing month/day tasks
/// - Day: Flat list (no grouping)
/// - Multiday: Groups entries by day within the range
struct EntryListGrouper: Sendable {
    let configuration: EntryListConfiguration

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
        configuration: EntryListConfiguration = .init(),
        period: Period,
        spreadDate: Date,
        spreadStartDate: Date? = nil,
        spreadEndDate: Date? = nil,
        calendar: Calendar
    ) {
        self.configuration = configuration
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
    func group(_ entries: [any Entry]) -> [EntryList.Section] {
        switch resolvedGroupingStyle {
        case .flat:
            guard !entries.isEmpty else { return [] }
            return flatSection(entries)
        case .byMonth:
            guard !entries.isEmpty else { return [] }
            return groupByMonth(entries)
        case .byDay:
            guard !entries.isEmpty else { return [] }
            return groupByDay(entries)
        case .byDayIncludingEmptyDates:
            return groupByDayIncludingEmptyDates(entries)
        case .byList:
            guard !entries.isEmpty else { return [] }
            return groupByList(entries)
        case .automatic:
            switch period {
            case .year:
                guard !entries.isEmpty else { return [] }
                return groupByMonth(entries)
            case .month:
                guard !entries.isEmpty else { return [] }
                return groupByDay(entries)
            case .day:
                guard !entries.isEmpty else { return [] }
                return groupByList(entries)
            case .multiday:
                return groupByDayIncludingEmptyDates(entries)
            }
        }
    }

    private var resolvedGroupingStyle: EntryListConfiguration.GroupingStyle {
        switch configuration.groupingStyle {
        case .automatic:
            switch period {
            case .year:
                return .byMonth
            case .month:
                return .byDay
            case .day:
                return .byList
            case .multiday:
                return .byDayIncludingEmptyDates
            }
        default:
            return configuration.groupingStyle
        }
    }

    // MARK: - Grouping Strategies

    /// Groups entries by month for year spreads.
    private func groupByMonth(_ entries: [any Entry]) -> [EntryList.Section] {
        var yearEntries: [any Entry] = []
        var monthGroups: [Date: [any Entry]] = [:]

        for entry in entries {
            let grouping = assignableGrouping(for: entry)

            switch grouping.period {
            case .year:
                yearEntries.append(entry)
            case .month, .day, .multiday:
                let monthStart = grouping.date.firstDayOfMonth(calendar: calendar) ?? grouping.date
                monthGroups[monthStart, default: []].append(entry)
            }
        }

        var sections: [EntryList.Section] = []
        let sortedYearEntries = sortEntriesChronologically(yearEntries)
        if !sortedYearEntries.isEmpty {
            sections.append(
                EntryList.Section(
                    id: sectionID(spreadDate),
                    title: "",
                    date: spreadDate,
                    entries: sortedYearEntries,
                    creationPeriod: .year,
                    creationDate: spreadDate
                )
            )
        }

        sections.append(
            contentsOf: monthGroups.keys.sorted().map { monthDate in
                let sortedEntries = sortEntriesChronologically(monthGroups[monthDate] ?? [])
                return EntryList.Section(
                    id: sectionID(monthDate),
                    title: formatMonthTitle(monthDate),
                    date: monthDate,
                    entries: sortedEntries,
                    creationPeriod: .month,
                    creationDate: monthDate
                )
            }
        )

        return sections
    }

    /// Groups entries by day for month and multiday spreads.
    private func groupByDay(_ entries: [any Entry]) -> [EntryList.Section] {
        return [
            EntryList.Section(
                id: sectionID(spreadDate),
                title: "",
                date: spreadDate,
                entries: sortEntriesChronologically(entries),
                creationPeriod: .month,
                creationDate: spreadDate
            )
        ]
    }

    /// Groups multiday entries by day while ensuring every covered day renders a section.
    private func groupByDayIncludingEmptyDates(_ entries: [any Entry]) -> [EntryList.Section] {
        let startDate = (spreadStartDate ?? spreadDate).startOfDay(calendar: calendar)
        let endDate = (spreadEndDate ?? spreadDate).startOfDay(calendar: calendar)

        let multidayEntries = sortEntriesChronologically(
            entries.filter { assignableGrouping(for: $0).period == .multiday }
        )
        var dayGroups: [Date: [any Entry]] = [:]
        for entry in entries {
            let grouping = assignableGrouping(for: entry)
            guard grouping.period == .day else { continue }
            let entryDate = grouping.date.startOfDay(calendar: calendar)
            dayGroups[entryDate, default: []].append(entry)
        }

        var sections: [EntryList.Section] = []
        if !multidayEntries.isEmpty {
            sections.append(
                EntryList.Section(
                    id: "multiday-header",
                    title: "This Range",
                    date: startDate,
                    entries: multidayEntries,
                    creationPeriod: .multiday,
                    creationDate: spreadDate
                )
            )
        }

        var currentDate = startDate
        while currentDate <= endDate {
            let sortedEntries = sortEntriesChronologically(dayGroups[currentDate] ?? [])
            sections.append(
                EntryList.Section(
                    id: sectionID(currentDate),
                    title: "",
                    date: currentDate,
                    entries: sortedEntries,
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
    private func flatSection(_ entries: [any Entry]) -> [EntryList.Section] {
        let sortedEntries = sortEntriesChronologically(entries)
        return [
            EntryList.Section(
                id: sectionID(spreadDate),
                title: "",
                date: spreadDate,
                entries: sortedEntries,
                creationPeriod: .day,
                creationDate: spreadDate
            )
        ]
    }

    /// Groups entries by their assigned list for day spreads.
    ///
    /// Named list sections appear in alphabetical order; tasks with no list appear last
    /// in an untitled section.
    private func groupByList(_ entries: [any Entry]) -> [EntryList.Section] {
        var listGroups: [UUID?: [any Entry]] = [:]
        var listNames: [UUID: String] = [:]

        for entry in entries {
            if let task = entry as? DataModel.Task {
                let listID = task.list?.id
                listGroups[listID, default: []].append(entry)
                if let list = task.list {
                    listNames[list.id] = list.name
                }
            } else {
                listGroups[nil, default: []].append(entry)
            }
        }

        var sections: [EntryList.Section] = []

        let sortedListIDs = listNames.keys.sorted { listNames[$0]! < listNames[$1]! }
        for listID in sortedListIDs {
            let listEntries = sortEntriesChronologically(listGroups[listID] ?? [])
            sections.append(EntryList.Section(
                id: listID.uuidString,
                title: listNames[listID] ?? "",
                date: spreadDate,
                entries: listEntries,
                creationPeriod: .day,
                creationDate: spreadDate
            ))
        }

        if let noListEntries = listGroups[nil], !noListEntries.isEmpty {
            sections.append(EntryList.Section(
                id: sectionID(spreadDate),
                title: "",
                date: spreadDate,
                entries: sortEntriesChronologically(noListEntries),
                creationPeriod: .day,
                creationDate: spreadDate
            ))
        }

        return sections
    }

    private func sectionID(_ date: Date) -> String {
        String(date.timeIntervalSinceReferenceDate)
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
}
