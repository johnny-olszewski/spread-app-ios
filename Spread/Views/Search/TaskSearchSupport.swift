import Foundation

struct TaskSearchSection: Identifiable {
    struct Row: Identifiable {
        let taskID: UUID
        let title: String
        let status: DataModel.Task.Status
        let period: Period
        let date: Date
        let selection: SpreadHeaderNavigatorModel.Selection?

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
        var selectionByID: [String: SpreadHeaderNavigatorModel.Selection] = [:]

        for task in journalManager.tasks where task.status != .cancelled {
            guard normalizedQuery.isEmpty || task.title.localizedCaseInsensitiveContains(normalizedQuery) else {
                continue
            }

            if let selection = selection(for: task) {
                let selectionID = selection.stableID(calendar: journalManager.calendar)
                selectionByID[selectionID] = selection
                spreadRowsByID[selectionID, default: []].append(row(for: task, selection: selection))
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

        let orderedSelections = selectionByID.values.sorted(by: isEarlier)
        sections.append(contentsOf: orderedSelections.compactMap { selection in
            let selectionID = selection.stableID(calendar: journalManager.calendar)
            guard let rows = spreadRowsByID[selectionID], !rows.isEmpty else { return nil }
            return TaskSearchSection(
                id: selectionID,
                title: sectionTitle(for: selection),
                token: selectionToken(for: selection),
                rows: rows.sorted(by: rowOrder)
            )
        })

        return sections
    }

    private func selection(for task: DataModel.Task) -> SpreadHeaderNavigatorModel.Selection? {
        switch journalManager.bujoMode {
        case .conventional:
            guard let spread = journalManager.currentDisplayedSpread(for: task) else { return nil }
            return .conventional(spread)
        case .traditional:
            switch task.period {
            case .year:
                return .traditionalYear(Period.year.normalizeDate(task.date, calendar: journalManager.calendar))
            case .month:
                return .traditionalMonth(Period.month.normalizeDate(task.date, calendar: journalManager.calendar))
            case .day:
                return .traditionalDay(Period.day.normalizeDate(task.date, calendar: journalManager.calendar))
            case .multiday:
                return nil
            }
        }
    }

    private func inboxRow(for task: DataModel.Task) -> TaskSearchSection.Row {
        TaskSearchSection.Row(
            taskID: task.id,
            title: task.title,
            status: task.status,
            period: task.period,
            date: task.date,
            selection: nil
        )
    }

    private func row(
        for task: DataModel.Task,
        selection: SpreadHeaderNavigatorModel.Selection
    ) -> TaskSearchSection.Row {
        TaskSearchSection.Row(
            taskID: task.id,
            title: task.title,
            status: task.status,
            period: task.period,
            date: task.date,
            selection: Optional(selection)
        )
    }

    private func sectionTitle(for selection: SpreadHeaderNavigatorModel.Selection) -> String {
        switch selection {
        case .conventional(let spread):
            return descriptiveTitle(for: spread.period, date: spread.date, startDate: spread.startDate, endDate: spread.endDate)
        case .traditionalYear(let date):
            return descriptiveTitle(for: .year, date: date)
        case .traditionalMonth(let date):
            return descriptiveTitle(for: .month, date: date)
        case .traditionalDay(let date):
            return descriptiveTitle(for: .day, date: date)
        }
    }

    private func selectionToken(for selection: SpreadHeaderNavigatorModel.Selection) -> String {
        Definitions.AccessibilityIdentifiers.token(sectionTitle(for: selection))
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

    private func isEarlier(
        _ lhs: SpreadHeaderNavigatorModel.Selection,
        _ rhs: SpreadHeaderNavigatorModel.Selection
    ) -> Bool {
        let lhsKey = sortKey(for: lhs)
        let rhsKey = sortKey(for: rhs)
        if lhsKey.date == rhsKey.date {
            return lhsKey.rank < rhsKey.rank
        }
        return lhsKey.date < rhsKey.date
    }

    private func sortKey(
        for selection: SpreadHeaderNavigatorModel.Selection
    ) -> (date: Date, rank: Int) {
        switch selection {
        case .conventional(let spread):
            let rank: Int = switch spread.period {
            case .year: 0
            case .month: 1
            case .multiday: 2
            case .day: 3
            }
            return (spread.startDate ?? spread.date, rank)
        case .traditionalYear(let date):
            return (Period.year.normalizeDate(date, calendar: journalManager.calendar), 0)
        case .traditionalMonth(let date):
            return (Period.month.normalizeDate(date, calendar: journalManager.calendar), 1)
        case .traditionalDay(let date):
            return (Period.day.normalizeDate(date, calendar: journalManager.calendar), 2)
        }
    }
}
