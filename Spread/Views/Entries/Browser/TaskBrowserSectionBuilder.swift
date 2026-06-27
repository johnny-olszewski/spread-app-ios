import Foundation

/// Builds ordered, filtered sections for the Entries tab task browser.
///
/// All filtering and ordering is pure — no side effects.
struct TaskBrowserSectionBuilder {

    let calendar: Calendar
    let today: Date

    /// Builds browser sections from the given tasks, applying search, list, and tag filters.
    ///
    /// Open tasks are split into subsections: an Inbox subsection (no preferred assignment)
    /// followed by one subsection per unique date+period combination, ordered ascending.
    /// Completed/Cancelled tasks appear last in a single section.
    ///
    /// - Parameters:
    ///   - tasks: All tasks to organize. Migrated tasks are silently excluded.
    ///   - selectedList: When non-nil, only tasks belonging to this list are included.
    ///   - selectedTagIDs: When non-empty, only tasks with at least one matching tag are included (OR).
    ///   - searchText: When non-empty, filters tasks whose title or body contains the query.
    /// - Returns: Inbox and dated subsections for open tasks, followed by Completed / Cancelled.
    func build(
        tasks: [DataModel.Task],
        selectedList: DataModel.List?,
        selectedTagIDs: Set<UUID>,
        searchText: String
    ) -> [TaskBrowserSection] {
        let filtered = applyFilters(
            to: tasks,
            selectedList: selectedList,
            selectedTagIDs: selectedTagIDs,
            searchText: searchText
        )

        let openTasks = filtered.filter { $0.status == .open }
        let terminalRows = sortedTerminal(filtered.filter { $0.status == .complete || $0.status == .cancelled })
            .map { TaskBrowserRow(task: $0) }

        var sections: [TaskBrowserSection] = []
        sections += openSections(from: openTasks)
        sections.append(TaskBrowserSection(kind: .terminal, title: "Completed / Cancelled", rows: terminalRows))
        return sections
    }

    // MARK: - Open Section Building

    private func openSections(from tasks: [DataModel.Task]) -> [TaskBrowserSection] {
        let inboxTasks = tasks
            .filter { $0.date == nil }
            .sorted { $0.createdDate < $1.createdDate }

        let assignedTasks = tasks
            .filter { $0.date != nil }
            .sorted { a, b in
                let aDate = a.date ?? a.createdDate
                let bDate = b.date ?? b.createdDate
                if aDate != bDate { return aDate < bDate }
                let ap = (a.period ?? .day).browserSortPriority
                let bp = (b.period ?? .day).browserSortPriority
                if ap != bp { return ap < bp }
                return a.createdDate < b.createdDate
            }

        var sections: [TaskBrowserSection] = []

        if !inboxTasks.isEmpty {
            sections.append(TaskBrowserSection(
                kind: .inbox,
                title: "Inbox",
                rows: inboxTasks.map { TaskBrowserRow(task: $0) }
            ))
        }

        // Group assigned tasks by unique (date, period) pairs in order.
        var seen: [String: Bool] = [:]
        var orderedKeys: [(Date, Period)] = []
        for task in assignedTasks {
            let date = task.date ?? task.createdDate
            let period = task.period ?? .day
            let key = "\(date.timeIntervalSinceReferenceDate)-\(period.rawValue)"
            if seen[key] == nil {
                seen[key] = true
                orderedKeys.append((date, period))
            }
        }

        for (date, period) in orderedKeys {
            let rows = assignedTasks
                .filter { ($0.date ?? $0.createdDate) == date && ($0.period ?? .day) == period }
                .map { TaskBrowserRow(task: $0) }
            sections.append(TaskBrowserSection(
                kind: .dated(date, period),
                title: sectionTitle(for: date, period: period),
                rows: rows
            ))
        }

        return sections
    }

    // MARK: - Section Title Formatting

    private func sectionTitle(for date: Date, period: Period) -> String {
        switch period {
        case .day:
            return dayTitle(for: date)
        case .month:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        case .year:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func dayTitle(for date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Filtering

    private func applyFilters(
        to tasks: [DataModel.Task],
        selectedList: DataModel.List?,
        selectedTagIDs: Set<UUID>,
        searchText: String
    ) -> [DataModel.Task] {
        tasks.filter { task in
            if let list = selectedList {
                guard task.list?.id == list.id else { return false }
            }
            if !selectedTagIDs.isEmpty {
                let taskTagIDs = Set(task.tags.map { $0.id })
                guard !taskTagIDs.isDisjoint(with: selectedTagIDs) else { return false }
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let titleMatch = task.title.lowercased().contains(query)
                let bodyMatch = task.body?.lowercased().contains(query) ?? false
                guard titleMatch || bodyMatch else { return false }
            }
            return true
        }
    }

    // MARK: - Ordering

    /// Orders terminal tasks by their most recent `statusUpdatedAt` desc, then `createdDate` desc.
    private func sortedTerminal(_ tasks: [DataModel.Task]) -> [DataModel.Task] {
        tasks.sorted { a, b in
            let aDate = latestStatusDate(a)
            let bDate = latestStatusDate(b)
            switch (aDate, bDate) {
            case let (a?, b?): return a > b
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.createdDate > b.createdDate
            }
        }
    }

    private func latestStatusDate(_ task: DataModel.Task) -> Date? {
        task.currentAssignments
            .filter { $0.status == .complete || $0.status == .cancelled }
            .compactMap { $0.statusUpdatedAt }
            .max()
    }
}

private extension Period {
    /// Sort priority for open-section ordering — lower value sorts first.
    var browserSortPriority: Int {
        switch self {
        case .day: 0
        case .month: 1
        case .year: 2
        case .multiday: 3
        }
    }
}
