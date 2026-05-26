import Foundation

struct TaskSearchSection: Identifiable {
    struct Row: Identifiable {
        let taskID: UUID
        let title: String
        let bodyPreview: String?
        let priority: DataModel.Task.Priority
        let dueDate: Date?
        let status: DataModel.Task.Status
        let period: Period
        let date: Date
        let hasPreferredAssignment: Bool
        let selection: DataModel.Spread?

        var id: UUID { taskID }
    }

    let id: String
    let title: String
    let token: String
    let rows: [Row]
}

struct TaskSearchSectionBuilder {
    let journalManager: JournalManager

    func build(searchText: String) -> [TaskSearchSection] {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        var inboxRows: [TaskSearchSection.Row] = []
        var spreadRowsByID: [String: [TaskSearchSection.Row]] = [:]
        var selectionByID: [String: DataModel.Spread] = [:]

        for task in journalManager.tasks where task.status != .cancelled {
            guard matches(task, query: normalizedQuery) else {
                continue
            }

            if let spread = selection(for: task) {
                let selectionID = spread.stableID(calendar: journalManager.calendar)
                selectionByID[selectionID] = spread
                spreadRowsByID[selectionID, default: []].append(row(for: task, selection: spread))
            } else {
                inboxRows.append(inboxRow(for: task))
            }
        }

        var sections: [TaskSearchSection] = []
        if !inboxRows.isEmpty {
            sections.append(
                TaskSearchSection(
                    id: "inbox",
                    title: "Inbox",
                    token: "inbox",
                    rows: inboxRows.sorted(by: rowOrder)
                )
            )
        }

        let orderedSpreads = selectionByID.values.sorted(by: isEarlier)
        sections.append(contentsOf: orderedSpreads.compactMap { spread in
            let selectionID = spread.stableID(calendar: journalManager.calendar)
            guard let rows = spreadRowsByID[selectionID], !rows.isEmpty else { return nil }
            return TaskSearchSection(
                id: selectionID,
                title: sectionTitle(for: spread),
                token: selectionToken(for: spread),
                rows: rows.sorted(by: rowOrder)
            )
        })

        return sections
    }

    private func selection(for task: DataModel.Task) -> DataModel.Spread? {
        guard task.hasPreferredAssignment else { return nil }
        return journalManager.currentDisplayedSpread(for: task)
    }

    private func inboxRow(for task: DataModel.Task) -> TaskSearchSection.Row {
        TaskSearchSection.Row(
            taskID: task.id,
            title: task.title,
            bodyPreview: task.bodyPreview,
            priority: task.priority,
            dueDate: task.dueDate,
            status: task.status,
            period: task.period,
            date: task.date,
            hasPreferredAssignment: task.hasPreferredAssignment,
            selection: nil
        )
    }

    private func row(
        for task: DataModel.Task,
        selection: DataModel.Spread
    ) -> TaskSearchSection.Row {
        TaskSearchSection.Row(
            taskID: task.id,
            title: task.title,
            bodyPreview: task.bodyPreview,
            priority: task.priority,
            dueDate: task.dueDate,
            status: task.status,
            period: task.period,
            date: task.date,
            hasPreferredAssignment: task.hasPreferredAssignment,
            selection: selection
        )
    }

    private func matches(_ task: DataModel.Task, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if task.title.localizedCaseInsensitiveContains(query) {
            return true
        }
        return task.body?.localizedCaseInsensitiveContains(query) == true
    }

    private func sectionTitle(for spread: DataModel.Spread) -> String {
        descriptiveTitle(
            for: spread.period,
            date: spread.date,
            startDate: spread.startDate,
            endDate: spread.endDate
        )
    }

    private func selectionToken(for spread: DataModel.Spread) -> String {
        Definitions.AccessibilityIdentifiers.token(sectionTitle(for: spread))
    }

    private func descriptiveTitle(
        for period: Period,
        date: Date,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.timeZone = journalManager.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")

        switch period {
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: Period.year.normalizeDate(date, calendar: journalManager.calendar))
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return formatter.string(from: Period.month.normalizeDate(date, calendar: journalManager.calendar))
        case .day:
            formatter.dateStyle = .long
            return formatter.string(from: Period.day.normalizeDate(date, calendar: journalManager.calendar))
        case .multiday:
            let start = startDate ?? date
            let end = endDate ?? date
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            let startText = formatter.string(from: start)
            let endText = formatter.string(from: end)
            let year = journalManager.calendar.component(.year, from: end)
            return "\(startText) – \(endText), \(year)"
        }
    }

    private func rowOrder(_ lhs: TaskSearchSection.Row, _ rhs: TaskSearchSection.Row) -> Bool {
        if lhs.status == rhs.status {
            if lhs.date == rhs.date {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.date < rhs.date
        }

        return lhs.status.rawValue < rhs.status.rawValue
    }

    private func isEarlier(_ lhs: DataModel.Spread, _ rhs: DataModel.Spread) -> Bool {
        let lhsKey = sortKey(for: lhs)
        let rhsKey = sortKey(for: rhs)
        if lhsKey.date == rhsKey.date {
            return lhsKey.rank < rhsKey.rank
        }
        return lhsKey.date < rhsKey.date
    }

    private func sortKey(for spread: DataModel.Spread) -> (date: Date, rank: Int) {
        let rank: Int = switch spread.period {
        case .year: 0
        case .month: 1
        case .multiday: 2
        case .day: 3
        }
        return (spread.startDate ?? spread.date, rank)
    }
}
