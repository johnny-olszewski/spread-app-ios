import Foundation

/// Builds ordered, filtered sections for the Entries tab task browser.
///
/// All filtering and ordering is pure — no side effects.
struct TaskBrowserSectionBuilder {

    /// Builds browser sections from the given tasks, applying search, list, and tag filters.
    ///
    /// - Parameters:
    ///   - tasks: All tasks to organize. Migrated tasks are silently excluded.
    ///   - selectedList: When non-nil, only tasks belonging to this list are included.
    ///   - selectedTagIDs: When non-empty, only tasks with at least one matching tag are included (OR).
    ///   - searchText: When non-empty, filters tasks whose title or body contains the query.
    /// - Returns: An Open section (top) and a Completed / Cancelled section (bottom).
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

        let openRows = sortedOpen(filtered.filter { $0.status == .open })
            .map { TaskBrowserRow(task: $0) }
        let terminalRows = sortedTerminal(filtered.filter { $0.status == .complete || $0.status == .cancelled })
            .map { TaskBrowserRow(task: $0) }

        return [
            TaskBrowserSection(kind: .open, rows: openRows),
            TaskBrowserSection(kind: .terminal, rows: terminalRows)
        ]
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

    /// Orders open tasks: Inbox tasks first (by `createdDate` asc), then assigned tasks by
    /// preferred date asc → period tiebreaker (day < month < year) → `createdDate` asc.
    private func sortedOpen(_ tasks: [DataModel.Task]) -> [DataModel.Task] {
        let inbox = tasks
            .filter { !$0.hasPreferredAssignment }
            .sorted { $0.createdDate < $1.createdDate }
        let assigned = tasks
            .filter { $0.hasPreferredAssignment }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                let ap = a.period.browserSortPriority
                let bp = b.period.browserSortPriority
                if ap != bp { return ap < bp }
                return a.createdDate < b.createdDate
            }
        return inbox + assigned
    }

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
        task.assignments
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
