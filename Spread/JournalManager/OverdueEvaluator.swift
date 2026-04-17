import Foundation

/// Evaluates which open tasks are overdue across the entire journal.
///
/// A task is overdue when its due date — determined by either its current open spread
/// assignment or its preferred date — has fully passed relative to `today`.
///
/// Overdue thresholds by period:
/// - **Day**: The task's day has already ended (yesterday or earlier).
/// - **Month**: The full calendar month has passed (first day of next month ≤ today).
/// - **Year**: The full calendar year has passed (first day of next year ≤ today).
/// - **Multiday**: Never considered overdue.
protocol OverdueEvaluator {
    /// Returns all open tasks that are currently overdue.
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - spreads: All existing spreads, used to locate a task's current open assignment.
    /// - Returns: `OverdueTaskItem` values for each overdue open task.
    func overdueTaskItems(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread]
    ) -> [OverdueTaskItem]
}

/// Standard implementation of `OverdueEvaluator`.
///
/// Uses `MigrationPlanner.currentDestinationSpread` to find where a task is currently
/// assigned. If an open spread is found, the spread's date is used for the overdue
/// check; otherwise the task's own preferred date is used (for Inbox tasks).
struct StandardOverdueEvaluator: OverdueEvaluator {
    /// The calendar used for date normalization and period boundary computation.
    let calendar: Calendar
    /// The reference date representing today, used to determine whether a date has passed.
    let today: Date
    /// Used to find the spread where the task currently has an open assignment.
    let migrationPlanner: any MigrationPlanner

    func overdueTaskItems(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread]
    ) -> [OverdueTaskItem] {
        tasks.compactMap { task in
            overdueTaskItem(for: task, spreads: spreads)
        }
    }

    private func overdueTaskItem(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> OverdueTaskItem? {
        guard task.status == .open else {
            return nil
        }

        if let openSpread = migrationPlanner.currentDestinationSpread(
            for: task,
            spreads: spreads,
            excluding: nil
        ) {
            let sourceKey = TaskReviewSourceKey(
                kind: .spread(
                    id: openSpread.id,
                    period: openSpread.period,
                    date: openSpread.period.normalizeDate(openSpread.date, calendar: calendar)
                )
            )
            guard isOverdue(date: openSpread.date, period: openSpread.period) else {
                return nil
            }
            return OverdueTaskItem(task: task, sourceKey: sourceKey)
        }

        guard isOverdue(date: task.date, period: task.period) else {
            return nil
        }
        return OverdueTaskItem(task: task, sourceKey: .init(kind: .inbox))
    }

    private func isOverdue(date: Date, period: Period) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)

        switch period {
        case .day:
            let dueDay = date.startOfDay(calendar: calendar)
            return todayStart > dueDay
        case .month:
            let startOfMonth = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return false
            }
            return todayStart >= startOfNextMonth
        case .year:
            let startOfYear = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return false
            }
            return todayStart >= startOfNextYear
        case .multiday:
            return false
        }
    }
}
